import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/collections/data/models/collection_sync_batch.dart';
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
      where:
          "clave IN ('01', '02', '03', '04', '99') "
          'AND deleted_at IS NULL',
      orderBy:
          "CASE clave WHEN '01' THEN 1 WHEN '04' THEN 2 "
          "WHEN '03' THEN 3 WHEN '02' THEN 4 WHEN '99' THEN 5 END",
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
          'sync': 0,
        });
      }
      for (final allocation in preview.allocations) {
        if (allocation.source == ReceivableSource.loan) {
          await transaction.insert('aplicaciones_prestamo', {
            'aplicacion_guid': const Uuid().v4(),
            'cobro_guid': collectionGuid,
            'prestamo_guid': allocation.loanGuid,
            'monto_aplicado': allocation.appliedAmount,
            'created_at': now.toIso8601String(),
            'sync': 0,
          });
        } else {
          await transaction.insert('aplicaciones_cobro', {
            'aplicacion_guid': const Uuid().v4(),
            'cobro_guid': collectionGuid,
            'cuenta_guid': allocation.accountGuid,
            'monto_aplicado': allocation.appliedAmount,
            'created_at': now.toIso8601String(),
            'sync': 0,
          });
        }
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

  Future<CollectionSyncBatch> getPendingSyncBatch() async {
    await backfillCreditSales();
    final db = await database.instance;
    final accounts = await db.query(
      'cuentas_por_cobrar',
      where: 'sync = 0',
      orderBy: 'created_at, cuenta_guid',
    );
    final collections = await db.rawQuery('''
      SELECT co.*,
        co.saldo_disponible + COALESCE((
          SELECT SUM(ap.monto_aplicado)
          FROM aplicaciones_prestamo ap
          WHERE ap.cobro_guid = co.cobro_guid
        ), 0) AS saldo_sync
      FROM cobros_cliente co
      WHERE co.sync = 0
      ORDER BY co.created_at, co.cobro_guid
    ''');
    final paymentForms = await db.query(
      'cobro_formas_pago',
      where: 'sync = 0',
      orderBy: 'pago_cobro_guid',
    );
    final applications = await db.query(
      'aplicaciones_cobro',
      where: 'sync = 0',
      orderBy: 'created_at, aplicacion_guid',
    );
    return CollectionSyncBatch(
      accounts: accounts
          .map(
            (row) => <String, Object?>{
              'cuentaGuid': row['cuenta_guid'],
              'pedidoGuid': row['pedido_guid'],
              'clienteGuid': row['cliente_guid'],
              'estatusGuid': row['estatus_guid'],
              'importeOriginal': row['importe_original'],
              'fechaEmision': row['fecha_emision'],
              'fechaVencimiento': row['fecha_vencimiento'],
              'bloqueada': row['bloqueada'] == 1,
              'createdAt': row['created_at'],
              'updatedAt': row['updated_at'],
            },
          )
          .toList(growable: false),
      collections: collections
          .map(
            (row) => <String, Object?>{
              'cobroGuid': row['cobro_guid'],
              'sucursalGuid': row['sucursal_guid'],
              'clienteGuid': row['cliente_guid'],
              'usuarioGuid': row['usuario_guid'],
              'fecha': row['fecha'],
              'montoTotal': row['monto_total'],
              // Cloud recibe provisionalmente como saldo la porción destinada
              // a préstamos; /prestamos/sincronizar la consume después.
              'saldoDisponible': row['saldo_sync'],
              'referencia': row['referencia'],
              'cancelado': row['cancelado'] == 1,
              'fechaCancelacion': row['fecha_cancelacion'],
              'motivoCancelacion': row['motivo_cancelacion'],
              'createdAt': row['created_at'],
              'updatedAt': row['updated_at'],
            },
          )
          .toList(growable: false),
      paymentForms: paymentForms
          .map(
            (row) => <String, Object?>{
              'pagoCobroGuid': row['pago_cobro_guid'],
              'cobroGuid': row['cobro_guid'],
              'formaPagoGuid': row['forma_pago_guid'],
              'monto': row['monto'],
              'referencia': row['referencia'],
            },
          )
          .toList(growable: false),
      applications: applications
          .map(
            (row) => <String, Object?>{
              'aplicacionGuid': row['aplicacion_guid'],
              'cobroGuid': row['cobro_guid'],
              'cuentaGuid': row['cuenta_guid'],
              'montoAplicado': row['monto_aplicado'],
              'createdAt': row['created_at'],
            },
          )
          .toList(growable: false),
    );
  }

  Future<void> markSyncCompleted(CollectionSyncResult result) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      await _markRows(
        transaction,
        table: 'cuentas_por_cobrar',
        guidColumn: 'cuenta_guid',
        guids: result.accounts,
      );
      await _markRows(
        transaction,
        table: 'cobros_cliente',
        guidColumn: 'cobro_guid',
        guids: result.collections,
      );
      await _markRows(
        transaction,
        table: 'cobro_formas_pago',
        guidColumn: 'pago_cobro_guid',
        guids: result.paymentForms,
      );
      await _markRows(
        transaction,
        table: 'aplicaciones_cobro',
        guidColumn: 'aplicacion_guid',
        guids: result.applications,
      );
    });
  }

  Future<String> getBranchGuid() async {
    final db = await database.instance;
    final rows = await db.query(
      'sucursales',
      columns: const ['guid'],
      limit: 1,
    );
    final guid = rows.isEmpty ? '' : rows.first['guid']?.toString() ?? '';
    if (guid.isEmpty) {
      throw const CollectionsLocalException(
        'No existe una sucursal activa para recuperar la cobranza.',
      );
    }
    return guid;
  }

  Future<CollectionsRecoveryResult> mergeCloudSnapshot(
    CollectionSyncBatch snapshot,
  ) async {
    final db = await database.instance;
    return db.transaction((transaction) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final clientGuids = await _guidSet(transaction, 'clientes', 'guid');
      final orderGuids = await _guidSet(transaction, 'pedidos', 'pedido_guid');
      final statusGuids = await _guidSet(transaction, 'estatus', 'guid');
      final paymentFormGuids = await _guidSet(
        transaction,
        'formas_pago',
        'guid',
      );
      final userNames = <String, String>{
        for (final row in await transaction.query(
          'usuarios',
          columns: const ['guid', 'nombre'],
        ))
          if ((row['guid']?.toString() ?? '').isNotEmpty)
            row['guid'].toString(): row['nombre']?.toString() ?? 'Usuario',
      };
      final accountGuids = await _guidSet(
        transaction,
        'cuentas_por_cobrar',
        'cuenta_guid',
      );
      final collectionGuids = await _guidSet(
        transaction,
        'cobros_cliente',
        'cobro_guid',
      );
      final pendingAccounts = await _pendingGuidSet(
        transaction,
        'cuentas_por_cobrar',
        'cuenta_guid',
      );
      final pendingCollections = await _pendingGuidSet(
        transaction,
        'cobros_cliente',
        'cobro_guid',
      );
      final pendingPaymentForms = await _pendingGuidSet(
        transaction,
        'cobro_formas_pago',
        'pago_cobro_guid',
      );
      final pendingApplications = await _pendingGuidSet(
        transaction,
        'aplicaciones_cobro',
        'aplicacion_guid',
      );

      var saved = 0;
      var preserved = 0;
      var omitted = 0;

      for (final row in snapshot.accounts) {
        final guid = _text(row, 'cuentaGuid');
        final clientGuid = _text(row, 'clienteGuid');
        final orderGuid = _text(row, 'pedidoGuid');
        final statusGuid = _text(row, 'estatusGuid');
        if (guid.isEmpty ||
            !clientGuids.contains(clientGuid) ||
            !orderGuids.contains(orderGuid) ||
            !statusGuids.contains(statusGuid)) {
          omitted++;
          continue;
        }
        if (pendingAccounts.contains(guid)) {
          preserved++;
          continue;
        }
        await _upsertCloudRow(
          transaction,
          table: 'cuentas_por_cobrar',
          guidColumn: 'cuenta_guid',
          guid: guid,
          values: {
            'cuenta_guid': guid,
            'cliente_guid': clientGuid,
            'pedido_guid': orderGuid,
            'importe_original': _value(row, 'importeOriginal'),
            'fecha_emision': _value(row, 'fechaEmision'),
            'fecha_vencimiento': _value(row, 'fechaVencimiento'),
            'estatus_guid': statusGuid,
            'bloqueada': _boolInt(_value(row, 'bloqueada')),
            'sync': 1,
            'created_at': _value(row, 'createdAt') ?? now,
            'updated_at': _value(row, 'updatedAt') ?? now,
          },
        );
        accountGuids.add(guid);
        saved++;
      }

      for (final row in snapshot.collections) {
        final guid = _text(row, 'cobroGuid');
        final clientGuid = _text(row, 'clienteGuid');
        if (guid.isEmpty || !clientGuids.contains(clientGuid)) {
          omitted++;
          continue;
        }
        if (pendingCollections.contains(guid)) {
          preserved++;
          continue;
        }
        final userGuid = _text(row, 'usuarioGuid');
        await _upsertCloudRow(
          transaction,
          table: 'cobros_cliente',
          guidColumn: 'cobro_guid',
          guid: guid,
          values: {
            'cobro_guid': guid,
            'sucursal_guid': _text(row, 'sucursalGuid'),
            'cliente_guid': clientGuid,
            'fecha': _value(row, 'fecha'),
            'monto_total': _value(row, 'montoTotal'),
            'saldo_disponible': _value(row, 'saldoDisponible') ?? 0,
            'referencia': _value(row, 'referencia'),
            'usuario_guid': userGuid.isEmpty ? null : userGuid,
            'usuario_nombre': userNames[userGuid] ?? 'Usuario',
            'cancelado': _boolInt(_value(row, 'cancelado')),
            'fecha_cancelacion': _value(row, 'fechaCancelacion'),
            'motivo_cancelacion': _value(row, 'motivoCancelacion'),
            'sync': 1,
            'created_at': _value(row, 'createdAt') ?? now,
            'updated_at': _value(row, 'updatedAt') ?? now,
          },
        );
        collectionGuids.add(guid);
        saved++;
      }

      for (final row in snapshot.paymentForms) {
        final guid = _text(row, 'pagoCobroGuid');
        final collectionGuid = _text(row, 'cobroGuid');
        final paymentFormGuid = _text(row, 'formaPagoGuid');
        if (guid.isEmpty ||
            !collectionGuids.contains(collectionGuid) ||
            !paymentFormGuids.contains(paymentFormGuid)) {
          omitted++;
          continue;
        }
        if (pendingPaymentForms.contains(guid)) {
          preserved++;
          continue;
        }
        await _upsertCloudRow(
          transaction,
          table: 'cobro_formas_pago',
          guidColumn: 'pago_cobro_guid',
          guid: guid,
          values: {
            'pago_cobro_guid': guid,
            'cobro_guid': collectionGuid,
            'forma_pago_guid': paymentFormGuid,
            'monto': _value(row, 'monto'),
            'referencia': _value(row, 'referencia'),
            'sync': 1,
          },
        );
        saved++;
      }

      for (final row in snapshot.applications) {
        final guid = _text(row, 'aplicacionGuid');
        final collectionGuid = _text(row, 'cobroGuid');
        final accountGuid = _text(row, 'cuentaGuid');
        if (guid.isEmpty ||
            !collectionGuids.contains(collectionGuid) ||
            !accountGuids.contains(accountGuid)) {
          omitted++;
          continue;
        }
        if (pendingApplications.contains(guid)) {
          preserved++;
          continue;
        }
        await _upsertCloudRow(
          transaction,
          table: 'aplicaciones_cobro',
          guidColumn: 'aplicacion_guid',
          guid: guid,
          values: {
            'aplicacion_guid': guid,
            'cobro_guid': collectionGuid,
            'cuenta_guid': accountGuid,
            'monto_aplicado': _value(row, 'montoAplicado'),
            'created_at': _value(row, 'createdAt') ?? now,
            'sync': 1,
          },
        );
        saved++;
      }

      return CollectionsRecoveryResult(
        received: snapshot.length,
        saved: saved,
        preservedPending: preserved,
        omittedMissingReferences: omitted,
      );
    });
  }

  Future<void> setAccountBlocked(String accountGuid, bool blocked) async {
    final db = await database.instance;
    final updated = await db.update(
      'cuentas_por_cobrar',
      {
        'bloqueada': blocked ? 1 : 0,
        'sync': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'cuenta_guid = ?',
      whereArgs: [accountGuid],
    );
    if (updated == 0) {
      final loanUpdated = await db.update(
        'prestamos_cliente',
        {
          'bloqueado': blocked ? 1 : 0,
          'sync': 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'prestamo_guid = ?',
        whereArgs: [accountGuid],
      );
      if (loanUpdated == 1) return;
    }
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
      ), applied_loans AS (
        SELECT ap.prestamo_guid, SUM(ap.monto_aplicado) AS total
        FROM aplicaciones_prestamo ap
        INNER JOIN cobros_cliente co ON co.cobro_guid = ap.cobro_guid
        WHERE co.cancelado = 0
        GROUP BY ap.prestamo_guid
      ), balances AS (
        SELECT
          cc.cliente_guid, cc.fecha_vencimiento, cc.bloqueada,
          MAX(cc.importe_original - COALESCE(a.total, 0), 0) AS saldo
        FROM cuentas_por_cobrar cc
        LEFT JOIN applied a ON a.cuenta_guid = cc.cuenta_guid
        LEFT JOIN estatus cxe ON cxe.guid = cc.estatus_guid
        WHERE LOWER(COALESCE(cxe.nombre, '')) <> 'cancelado'
        UNION ALL
        SELECT
          pr.cliente_guid, pr.fecha_vencimiento, pr.bloqueado,
          MAX(pr.monto - COALESCE(al.total, 0), 0) AS saldo
        FROM prestamos_cliente pr
        LEFT JOIN applied_loans al ON al.prestamo_guid = pr.prestamo_guid
        WHERE pr.cancelado = 0
      ), credits AS (
        SELECT cliente_guid, SUM(saldo_disponible) AS saldo_favor
        FROM cobros_cliente
        WHERE cancelado = 0
        GROUP BY cliente_guid
      )
      SELECT
        c.guid, c.nombre, c.correo, c.telefono, c.monto_credito,
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
      GROUP BY c.guid, c.nombre, c.correo, c.telefono, c.monto_credito,
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
      email: row['correo']?.toString() ?? '',
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
      SELECT * FROM (
      SELECT
        cc.cuenta_guid, cc.pedido_guid, NULL AS prestamo_guid,
        cc.importe_original, cc.fecha_emision, cc.fecha_vencimiento,
        COALESCE(cxe.nombre, 'Sin estatus') AS estatus_nombre,
        cc.bloqueada, p.folio, 'venta' AS origen,
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
      UNION ALL
      SELECT
        pr.prestamo_guid AS cuenta_guid, '' AS pedido_guid,
        pr.prestamo_guid, pr.monto AS importe_original,
        pr.fecha AS fecha_emision, pr.fecha_vencimiento,
        CASE
          WHEN pr.monto - COALESCE((
            SELECT SUM(ap.monto_aplicado)
            FROM aplicaciones_prestamo ap
            INNER JOIN cobros_cliente co ON co.cobro_guid = ap.cobro_guid
            WHERE ap.prestamo_guid = pr.prestamo_guid AND co.cancelado = 0
          ), 0) <= 0.001 THEN 'Liquidada'
          WHEN pr.fecha_vencimiento < ? THEN 'Vencida'
          ELSE 'Pendiente'
        END AS estatus_nombre,
        pr.bloqueado AS bloqueada, 0 AS folio, 'prestamo' AS origen,
        COALESCE((
          SELECT SUM(ap.monto_aplicado)
          FROM aplicaciones_prestamo ap
          INNER JOIN cobros_cliente co ON co.cobro_guid = ap.cobro_guid
          WHERE ap.prestamo_guid = pr.prestamo_guid AND co.cancelado = 0
        ), 0) AS abonado
      FROM prestamos_cliente pr
      WHERE pr.cliente_guid = ? AND pr.cancelado = 0
        ${includeBlocked ? '' : 'AND pr.bloqueado = 0'}
        AND pr.monto - COALESCE((
          SELECT SUM(ap2.monto_aplicado)
          FROM aplicaciones_prestamo ap2
          INNER JOIN cobros_cliente co2 ON co2.cobro_guid = ap2.cobro_guid
          WHERE ap2.prestamo_guid = pr.prestamo_guid AND co2.cancelado = 0
        ), 0) > 0.001
      ) ORDER BY fecha_vencimiento, fecha_emision, folio
    ''',
      [clientGuid, DateTime.now().toUtc().toIso8601String(), clientGuid],
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
            source: row['origen'] == 'prestamo'
                ? ReceivableSource.loan
                : ReceivableSource.sale,
            loanGuid: row['prestamo_guid']?.toString(),
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
        ), 0) + COALESCE((
          SELECT SUM(ap.monto_aplicado)
          FROM aplicaciones_prestamo ap
          WHERE ap.cobro_guid = co.cobro_guid
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
          pr.prestamo_guid AS guid,
          NULL AS pedido_guid,
          'cargo' AS tipo,
          pr.fecha,
          'Préstamo' AS descripcion,
          pr.monto AS monto
        FROM prestamos_cliente pr
        WHERE pr.cliente_guid = ? AND pr.cancelado = 0
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
      [clientGuid, clientGuid, clientGuid],
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

  Future<void> _markRows(
    DatabaseExecutor database, {
    required String table,
    required String guidColumn,
    required List<String> guids,
  }) async {
    const chunkSize = 400;
    for (var start = 0; start < guids.length; start += chunkSize) {
      final end = start + chunkSize < guids.length
          ? start + chunkSize
          : guids.length;
      final chunk = guids.sublist(start, end);
      await database.update(
        table,
        const {'sync': 1},
        where: '$guidColumn IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
    }
  }

  Future<Set<String>> _guidSet(
    DatabaseExecutor database,
    String table,
    String column,
  ) async => (await database.query(table, columns: [column]))
      .map((row) => row[column]?.toString() ?? '')
      .where((value) => value.isNotEmpty)
      .toSet();

  Future<Set<String>> _pendingGuidSet(
    DatabaseExecutor database,
    String table,
    String column,
  ) async => (await database.query(
    table,
    columns: [column],
    where: 'sync = 0',
  )).map((row) => row[column]?.toString() ?? '').toSet();

  Future<void> _upsertCloudRow(
    DatabaseExecutor database, {
    required String table,
    required String guidColumn,
    required String guid,
    required Map<String, Object?> values,
  }) async {
    final existing = await database.query(
      table,
      columns: [guidColumn],
      where: '$guidColumn = ?',
      whereArgs: [guid],
      limit: 1,
    );
    if (existing.isEmpty) {
      await database.insert(table, values);
      return;
    }
    final updates = Map<String, Object?>.from(values)..remove(guidColumn);
    await database.update(
      table,
      updates,
      where: '$guidColumn = ?',
      whereArgs: [guid],
    );
  }

  static Object? _value(Map<String, Object?> row, String key) {
    if (row.containsKey(key)) return row[key];
    final pascal = key.isEmpty
        ? key
        : '${key[0].toUpperCase()}${key.substring(1)}';
    return row[pascal];
  }

  static String _text(Map<String, Object?> row, String key) =>
      _value(row, key)?.toString() ?? '';

  static int _boolInt(Object? value) =>
      value == true || value == 1 || value?.toString().toLowerCase() == 'true'
      ? 1
      : 0;

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
