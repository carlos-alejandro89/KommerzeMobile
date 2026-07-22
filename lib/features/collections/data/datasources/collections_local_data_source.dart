import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/collections/domain/entities/collection_models.dart';
import 'package:kommerze_mobile/features/collections/domain/services/collection_allocation_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class CollectionsLocalDataSource {
  static const _purchaseTypeGuid = 'c82164a9-616c-4148-80fd-c4702d8a7cca';
  final AppDatabase database;

  const CollectionsLocalDataSource(this.database);

  Future<void> backfillCreditSales() async {
    final db = await database.instance;
    final rows = await db.rawQuery(
      '''
      SELECT
        p.pedido_guid, p.cliente_guid, p.fecha,
        COALESCE(c.dias_credito, 0) AS dias_credito,
        COALESCE(SUM(
          d.cantidad * d.precio_venta * (1 - d.descuento / 100.0)
        ), 0) AS total,
        COALESCE((
          SELECT SUM(pv.monto)
          FROM pagos_venta pv
          WHERE pv.pedido_guid = p.pedido_guid AND pv.es_credito = 0
        ), 0) AS cobrado
      FROM pedidos p
      INNER JOIN clientes c ON c.guid = p.cliente_guid
      INNER JOIN pedido_detalle d ON d.pedido_guid = p.pedido_guid
      LEFT JOIN estatus e ON e.guid = p.estatus_guid
      LEFT JOIN cuentas_por_cobrar cc ON cc.pedido_guid = p.pedido_guid
      WHERE p.es_credito = 1
        AND p.tipo_pedido_guid <> ?
        AND cc.cuenta_guid IS NULL
        AND LOWER(COALESCE(e.nombre, '')) <> 'cancelado'
      GROUP BY p.pedido_guid, p.cliente_guid, p.fecha, c.dias_credito
    ''',
      [_purchaseTypeGuid],
    );
    await db.transaction((transaction) async {
      final pendingStatusGuid = rows.isEmpty
          ? null
          : await _statusGuid(transaction, 'Pendiente');
      final overdueStatusGuid = rows.isEmpty
          ? null
          : await _statusGuid(transaction, 'Vencida');
      for (final row in rows) {
        final amount = _decimal(row['total']) - _decimal(row['cobrado']);
        await transaction.delete(
          'pagos_venta',
          where: 'pedido_guid = ? AND es_credito = 1',
          whereArgs: [row['pedido_guid']],
        );
        if (amount <= .001) continue;
        final issuedAt = DateTime.parse(row['fecha'].toString()).toUtc();
        final dueAt = issuedAt.add(
          Duration(days: _integer(row['dias_credito'])),
        );
        final now = DateTime.now().toUtc();
        await transaction.insert('cuentas_por_cobrar', {
          'cuenta_guid': const Uuid().v4(),
          'cliente_guid': row['cliente_guid'],
          'pedido_guid': row['pedido_guid'],
          'importe_original': amount,
          'fecha_emision': issuedAt.toIso8601String(),
          'fecha_vencimiento': dueAt.toIso8601String(),
          'estatus_guid': dueAt.isBefore(now)
              ? overdueStatusGuid
              : pendingStatusGuid,
          'bloqueada': 0,
          'sync': 0,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await transaction.rawDelete('''
        DELETE FROM pagos_venta
        WHERE es_credito = 1 AND EXISTS (
          SELECT 1 FROM cuentas_por_cobrar cc
          WHERE cc.pedido_guid = pagos_venta.pedido_guid
        )
      ''');
    });
  }

  Future<CollectionDashboard> getDashboard() async {
    await backfillCreditSales();
    final db = await database.instance;
    final clients = await _clientSummaries(db);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = start.add(const Duration(days: 1));
    final collectedRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(monto_total), 0) AS total
      FROM cobros_cliente
      WHERE cancelado = 0 AND fecha >= ? AND fecha < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return CollectionDashboard(
      clients: clients,
      totalReceivable: clients.fold(0, (sum, item) => sum + item.balance),
      overdueReceivable: clients.fold(
        0,
        (sum, item) => sum + item.overdueBalance,
      ),
      collectedToday: _decimal(collectedRows.first['total']),
    );
  }

  Future<CollectionClientDetail> getClientDetail(String clientGuid) async {
    await backfillCreditSales();
    final db = await database.instance;
    final summary = await _clientSummary(db, clientGuid);
    if (summary == null) {
      throw const CollectionsLocalException(
        'El cliente ya no está disponible.',
      );
    }
    return CollectionClientDetail(
      client: summary,
      accounts: await _openAccounts(db, clientGuid, includeBlocked: true),
      collections: await _collectionHistory(db, clientGuid),
      statement: await _statement(db, clientGuid),
    );
  }

  Future<List<PaymentFormOption>> getPaymentForms() async {
    final db = await database.instance;
    final rows = await db.query(
      'formas_pago',
      columns: const ['guid', 'clave', 'descripcion'],
      where: "clave <> '99' AND deleted_at IS NULL",
      orderBy:
          "CASE clave WHEN '01' THEN 1 WHEN '03' THEN 2 "
          "WHEN '04' THEN 3 WHEN '28' THEN 4 WHEN '02' THEN 5 ELSE 9 END, clave",
    );
    return rows
        .map(
          (row) => PaymentFormOption(
            guid: row['guid']?.toString() ?? '',
            key: row['clave']?.toString() ?? '',
            description: row['descripcion']?.toString() ?? '',
          ),
        )
        .where((item) => item.guid.isNotEmpty)
        .toList(growable: false);
  }

  Future<CollectionPreview> preview(
    String clientGuid,
    List<CollectionPaymentInput> payments,
  ) async {
    final db = await database.instance;
    return allocateCollectionPayment(
      await _openAccounts(db, clientGuid),
      _validTotal(payments),
    );
  }

  Future<CollectionReceipt> createCollection({
    required String clientGuid,
    required List<CollectionPaymentInput> payments,
    required String userGuid,
    required String userName,
  }) async {
    final total = _validTotal(payments);
    if (total <= .001) {
      throw const CollectionsLocalException(
        'Agrega al menos una forma de pago con un monto válido.',
      );
    }
    final db = await database.instance;
    return db.transaction((transaction) async {
      final clientRows = await transaction.query(
        'clientes',
        columns: const ['nombre'],
        where: 'guid = ? AND deleted_at IS NULL',
        whereArgs: [clientGuid],
        limit: 1,
      );
      if (clientRows.isEmpty) {
        throw const CollectionsLocalException(
          'El cliente ya no está disponible.',
        );
      }
      final branchRows = await transaction.query(
        'sucursales',
        columns: const ['guid'],
        limit: 1,
      );
      if (branchRows.isEmpty) {
        throw const CollectionsLocalException('No existe una sucursal activa.');
      }
      final preview = allocateCollectionPayment(
        await _openAccounts(transaction, clientGuid),
        total,
      );
      final now = DateTime.now().toUtc();
      final collectionGuid = const Uuid().v4();
      final references = payments
          .map((item) => item.reference.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .join(' · ');
      await transaction.insert('cobros_cliente', {
        'cobro_guid': collectionGuid,
        'sucursal_guid': branchRows.first['guid'],
        'cliente_guid': clientGuid,
        'fecha': now.toIso8601String(),
        'monto_total': total,
        'saldo_disponible': preview.creditBalance,
        'referencia': references,
        'usuario_guid': userGuid,
        'usuario_nombre': userName,
        'cancelado': 0,
        'sync': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      for (final payment in payments.where((item) => item.amount > .001)) {
        await transaction.insert('cobro_formas_pago', {
          'pago_cobro_guid': const Uuid().v4(),
          'cobro_guid': collectionGuid,
          'forma_pago_guid': payment.paymentForm.guid,
          'monto': payment.amount,
          'referencia': payment.reference.trim(),
        });
      }
      for (final allocation in preview.allocations) {
        await transaction.insert('aplicaciones_cobro', {
          'aplicacion_guid': const Uuid().v4(),
          'cobro_guid': collectionGuid,
          'cuenta_guid': allocation.accountGuid,
          'monto_aplicado': allocation.appliedAmount,
          'created_at': now.toIso8601String(),
        });
      }
      await _refreshStatuses(transaction, clientGuid);
      return CollectionReceipt(
        collectionGuid: collectionGuid,
        date: now.toLocal(),
        clientName: clientRows.first['nombre']?.toString() ?? '',
        preview: preview,
        payments: List.unmodifiable(payments),
      );
    });
  }

  Future<void> setAccountBlocked(String accountGuid, bool blocked) async {
    final db = await database.instance;
    final updated = await db.update(
      'cuentas_por_cobrar',
      {
        'bloqueada': blocked ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'cuenta_guid = ?',
      whereArgs: [accountGuid],
    );
    if (updated != 1) {
      throw const CollectionsLocalException(
        'No fue posible actualizar la cuenta.',
      );
    }
  }

  Future<void> cancelCollection(String collectionGuid, String reason) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      final rows = await transaction.query(
        'cobros_cliente',
        columns: const ['cliente_guid', 'cancelado'],
        where: 'cobro_guid = ?',
        whereArgs: [collectionGuid],
        limit: 1,
      );
      if (rows.isEmpty || rows.first['cancelado'] == 1) {
        throw const CollectionsLocalException(
          'El cobro no está disponible para cancelación.',
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await transaction.update(
        'cobros_cliente',
        {
          'cancelado': 1,
          'fecha_cancelacion': now,
          'motivo_cancelacion': reason.trim(),
          'saldo_disponible': 0,
          'sync': 0,
          'updated_at': now,
        },
        where: 'cobro_guid = ?',
        whereArgs: [collectionGuid],
      );
      await _refreshStatuses(
        transaction,
        rows.first['cliente_guid']?.toString() ?? '',
      );
    });
  }

  Future<List<CollectionClientSummary>> _clientSummaries(
    DatabaseExecutor database,
  ) async {
    final rows = await _summaryRows(database);
    return rows
        .map(_summaryFromMap)
        .where((item) => item.balance > .001 || item.creditBalance > .001)
        .toList(growable: false);
  }

  Future<CollectionClientSummary?> _clientSummary(
    DatabaseExecutor database,
    String clientGuid,
  ) async {
    final rows = await _summaryRows(database, clientGuid: clientGuid);
    return rows.isEmpty ? null : _summaryFromMap(rows.first);
  }

  Future<List<Map<String, Object?>>> _summaryRows(
    DatabaseExecutor database, {
    String? clientGuid,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return database.rawQuery(
      '''
      WITH applied AS (
        SELECT ac.cuenta_guid, SUM(ac.monto_aplicado) AS total
        FROM aplicaciones_cobro ac
        INNER JOIN cobros_cliente co ON co.cobro_guid = ac.cobro_guid
        WHERE co.cancelado = 0
        GROUP BY ac.cuenta_guid
      ), balances AS (
        SELECT
          cc.cliente_guid, cc.fecha_vencimiento, cc.bloqueada,
          MAX(cc.importe_original - COALESCE(a.total, 0), 0) AS saldo
        FROM cuentas_por_cobrar cc
        LEFT JOIN applied a ON a.cuenta_guid = cc.cuenta_guid
        LEFT JOIN estatus cxe ON cxe.guid = cc.estatus_guid
        WHERE LOWER(COALESCE(cxe.nombre, '')) <> 'cancelado'
      ), credits AS (
        SELECT cliente_guid, SUM(saldo_disponible) AS saldo_favor
        FROM cobros_cliente
        WHERE cancelado = 0
        GROUP BY cliente_guid
      )
      SELECT
        c.guid, c.nombre, c.rfc, c.telefono, c.monto_credito,
        COALESCE(SUM(b.saldo), 0) AS saldo,
        COALESCE(SUM(CASE WHEN b.fecha_vencimiento < ? THEN b.saldo ELSE 0 END), 0)
          AS vencido,
        COALESCE(cr.saldo_favor, 0) AS saldo_favor,
        SUM(CASE WHEN b.saldo > 0.001 THEN 1 ELSE 0 END) AS cuentas_abiertas,
        MIN(CASE WHEN b.saldo > 0.001 THEN b.fecha_vencimiento END)
          AS vencimiento_mas_antiguo
      FROM clientes c
      LEFT JOIN balances b ON b.cliente_guid = c.guid
      LEFT JOIN credits cr ON cr.cliente_guid = c.guid
      WHERE c.deleted_at IS NULL
        ${clientGuid == null ? '' : 'AND c.guid = ?'}
      GROUP BY c.guid, c.nombre, c.rfc, c.telefono, c.monto_credito,
        cr.saldo_favor
      ORDER BY vencido DESC, saldo DESC, c.nombre COLLATE NOCASE
    ''',
      [now, ?clientGuid],
    );
  }

  CollectionClientSummary _summaryFromMap(Map<String, Object?> row) {
    return CollectionClientSummary(
      clientGuid: row['guid']?.toString() ?? '',
      name: row['nombre']?.toString() ?? '',
      rfc: row['rfc']?.toString() ?? '',
      phone: row['telefono']?.toString() ?? '',
      creditLimit: _decimal(row['monto_credito']),
      balance: _decimal(row['saldo']),
      overdueBalance: _decimal(row['vencido']),
      creditBalance: _decimal(row['saldo_favor']),
      openAccounts: _integer(row['cuentas_abiertas']),
      oldestDueDate: _date(row['vencimiento_mas_antiguo']),
    );
  }

  Future<List<ReceivableAccount>> _openAccounts(
    DatabaseExecutor database,
    String clientGuid, {
    bool includeBlocked = false,
  }) async {
    final rows = await database.rawQuery(
      '''
      SELECT
        cc.cuenta_guid, cc.pedido_guid, cc.importe_original,
        cc.fecha_emision, cc.fecha_vencimiento,
        COALESCE(cxe.nombre, 'Sin estatus') AS estatus_nombre,
        cc.bloqueada,
        p.folio,
        COALESCE((
          SELECT SUM(ac.monto_aplicado)
          FROM aplicaciones_cobro ac
          INNER JOIN cobros_cliente co ON co.cobro_guid = ac.cobro_guid
          WHERE ac.cuenta_guid = cc.cuenta_guid AND co.cancelado = 0
        ), 0) AS abonado
      FROM cuentas_por_cobrar cc
      INNER JOIN pedidos p ON p.pedido_guid = cc.pedido_guid
      LEFT JOIN estatus cxe ON cxe.guid = cc.estatus_guid
      WHERE cc.cliente_guid = ?
        AND LOWER(COALESCE(cxe.nombre, '')) <> 'cancelado'
        ${includeBlocked ? '' : 'AND cc.bloqueada = 0'}
        AND cc.importe_original - COALESCE((
          SELECT SUM(ac2.monto_aplicado)
          FROM aplicaciones_cobro ac2
          INNER JOIN cobros_cliente co2 ON co2.cobro_guid = ac2.cobro_guid
          WHERE ac2.cuenta_guid = cc.cuenta_guid AND co2.cancelado = 0
        ), 0) > 0.001
      ORDER BY cc.fecha_vencimiento, cc.fecha_emision, p.folio
    ''',
      [clientGuid],
    );
    return rows
        .map(
          (row) => ReceivableAccount(
            accountGuid: row['cuenta_guid']?.toString() ?? '',
            orderGuid: row['pedido_guid']?.toString() ?? '',
            folio: _integer(row['folio']),
            originalAmount: _decimal(row['importe_original']),
            paidAmount: _decimal(row['abonado']),
            issuedAt: DateTime.parse(row['fecha_emision'].toString()).toLocal(),
            dueAt: DateTime.parse(
              row['fecha_vencimiento'].toString(),
            ).toLocal(),
            status: row['estatus_nombre']?.toString() ?? 'Sin estatus',
            blocked: row['bloqueada'] == 1,
          ),
        )
        .toList(growable: false);
  }

  Future<List<CollectionRecord>> _collectionHistory(
    DatabaseExecutor database,
    String clientGuid,
  ) async {
    final rows = await database.rawQuery(
      '''
      SELECT
        co.cobro_guid, co.fecha, co.monto_total, co.saldo_disponible,
        COALESCE(co.referencia, '') AS referencia,
        COALESCE(co.usuario_nombre, 'Usuario') AS usuario_nombre,
        co.cancelado,
        COALESCE((
          SELECT SUM(ac.monto_aplicado)
          FROM aplicaciones_cobro ac
          WHERE ac.cobro_guid = co.cobro_guid
        ), 0) AS aplicado,
        COALESCE((
          SELECT GROUP_CONCAT(fp.clave || ' - ' || fp.descripcion, '|||')
          FROM cobro_formas_pago cfp
          INNER JOIN formas_pago fp ON fp.guid = cfp.forma_pago_guid
          WHERE cfp.cobro_guid = co.cobro_guid
        ), '') AS formas
      FROM cobros_cliente co
      WHERE co.cliente_guid = ?
      ORDER BY co.fecha DESC
    ''',
      [clientGuid],
    );
    final appliedRows = await database.rawQuery(
      '''
      SELECT
        ac.cobro_guid, ac.cuenta_guid, cc.pedido_guid, p.folio,
        ac.monto_aplicado
      FROM aplicaciones_cobro ac
      INNER JOIN cuentas_por_cobrar cc
        ON cc.cuenta_guid = ac.cuenta_guid
      INNER JOIN pedidos p ON p.pedido_guid = cc.pedido_guid
      INNER JOIN cobros_cliente co ON co.cobro_guid = ac.cobro_guid
      WHERE co.cliente_guid = ?
      ORDER BY co.fecha DESC, cc.fecha_vencimiento, p.folio
      ''',
      [clientGuid],
    );
    final appliedByCollection = <String, List<CollectionAppliedSale>>{};
    for (final row in appliedRows) {
      final collectionGuid = row['cobro_guid']?.toString() ?? '';
      appliedByCollection
          .putIfAbsent(collectionGuid, () => [])
          .add(
            CollectionAppliedSale(
              accountGuid: row['cuenta_guid']?.toString() ?? '',
              orderGuid: row['pedido_guid']?.toString() ?? '',
              folio: _integer(row['folio']),
              appliedAmount: _decimal(row['monto_aplicado']),
            ),
          );
    }
    return rows
        .map((row) {
          final collectionGuid = row['cobro_guid']?.toString() ?? '';
          return CollectionRecord(
            collectionGuid: collectionGuid,
            date: DateTime.parse(row['fecha'].toString()).toLocal(),
            total: _decimal(row['monto_total']),
            applied: _decimal(row['aplicado']),
            creditBalance: _decimal(row['saldo_disponible']),
            reference: row['referencia']?.toString() ?? '',
            userName: row['usuario_nombre']?.toString() ?? '',
            cancelled: row['cancelado'] == 1,
            paymentForms: (row['formas']?.toString() ?? '').isEmpty
                ? const []
                : row['formas'].toString().split('|||'),
            appliedSales: appliedByCollection[collectionGuid] ?? const [],
          );
        })
        .toList(growable: false);
  }

  Future<List<AccountStatementMovement>> _statement(
    DatabaseExecutor database,
    String clientGuid,
  ) async {
    final rows = await database.rawQuery(
      '''
      SELECT guid, pedido_guid, tipo, fecha, descripcion, monto FROM (
        SELECT
          cc.cuenta_guid AS guid,
          cc.pedido_guid,
          'cargo' AS tipo,
          cc.fecha_emision AS fecha,
          'Venta VTA-' || printf('%06d', p.folio) AS descripcion,
          cc.importe_original AS monto
        FROM cuentas_por_cobrar cc
        INNER JOIN pedidos p ON p.pedido_guid = cc.pedido_guid
        LEFT JOIN estatus cxe ON cxe.guid = cc.estatus_guid
        WHERE cc.cliente_guid = ?
          AND LOWER(COALESCE(cxe.nombre, '')) <> 'cancelado'
        UNION ALL
        SELECT
          co.cobro_guid AS guid,
          NULL AS pedido_guid,
          'abono' AS tipo,
          co.fecha,
          'Cobro registrado' AS descripcion,
          -co.monto_total AS monto
        FROM cobros_cliente co
        WHERE co.cliente_guid = ? AND co.cancelado = 0
      )
      ORDER BY fecha, tipo DESC
    ''',
      [clientGuid, clientGuid],
    );
    var balance = 0.0;
    final movements = <AccountStatementMovement>[];
    for (final row in rows) {
      final amount = _decimal(row['monto']);
      balance += amount;
      movements.add(
        AccountStatementMovement(
          guid: row['guid']?.toString() ?? '',
          orderGuid: row['pedido_guid']?.toString(),
          type: row['tipo'] == 'cargo'
              ? AccountStatementMovementType.charge
              : AccountStatementMovementType.payment,
          date: DateTime.parse(row['fecha'].toString()).toLocal(),
          description: row['descripcion']?.toString() ?? '',
          amount: amount.abs(),
          runningBalance: balance,
        ),
      );
    }
    return movements.reversed.toList(growable: false);
  }

  Future<void> _refreshStatuses(
    DatabaseExecutor database,
    String clientGuid,
  ) async {
    final accounts = await database.rawQuery(
      '''
      SELECT cc.cuenta_guid, cc.importe_original, cc.fecha_vencimiento
      FROM cuentas_por_cobrar cc
      LEFT JOIN estatus e ON e.guid = cc.estatus_guid
      WHERE cc.cliente_guid = ?
        AND LOWER(COALESCE(e.nombre, '')) <> 'cancelado'
      ''',
      [clientGuid],
    );
    final now = DateTime.now().toUtc();
    for (final account in accounts) {
      final appliedRows = await database.rawQuery(
        '''
        SELECT COALESCE(SUM(ac.monto_aplicado), 0) AS total
        FROM aplicaciones_cobro ac
        INNER JOIN cobros_cliente co ON co.cobro_guid = ac.cobro_guid
        WHERE ac.cuenta_guid = ? AND co.cancelado = 0
        ''',
        [account['cuenta_guid']],
      );
      final original = _decimal(account['importe_original']);
      final applied = _decimal(appliedRows.first['total']);
      final balance = original - applied;
      final dueAt = DateTime.parse(account['fecha_vencimiento'].toString());
      final statusName = balance <= .001
          ? 'Liquidada'
          : applied > .001
          ? 'Parcial'
          : dueAt.isBefore(now)
          ? 'Vencida'
          : 'Pendiente';
      final statusGuid = await _statusGuid(database, statusName);
      await database.update(
        'cuentas_por_cobrar',
        {
          'estatus_guid': statusGuid,
          'sync': 0,
          'updated_at': now.toIso8601String(),
        },
        where: 'cuenta_guid = ?',
        whereArgs: [account['cuenta_guid']],
      );
    }
  }

  double _validTotal(List<CollectionPaymentInput> payments) {
    return payments
        .where((item) => item.amount.isFinite && item.amount > 0)
        .fold(0, (sum, item) => sum + item.amount);
  }

  Future<String> _statusGuid(
    DatabaseExecutor database,
    String statusName,
  ) async {
    final rows = await database.query(
      'estatus',
      columns: const ['guid'],
      where: 'LOWER(nombre) = LOWER(?) AND deleted_at IS NULL',
      whereArgs: [statusName],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw CollectionsLocalException(
        'El estatus $statusName no está disponible. Sincroniza el catálogo Estatus.',
      );
    }
    return rows.first['guid']?.toString() ?? '';
  }

  static double _decimal(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
  static DateTime? _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toLocal();
  }
}

class CollectionsLocalException implements Exception {
  final String message;
  const CollectionsLocalException(this.message);

  @override
  String toString() => message;
}

final collectionsLocalDataSourceProvider = Provider<CollectionsLocalDataSource>(
  (ref) => CollectionsLocalDataSource(ref.read(appDatabaseProvider)),
);
