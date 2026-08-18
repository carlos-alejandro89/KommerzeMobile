import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/loans/data/models/loan_sync_batch.dart';
import 'package:kommerze_mobile/features/loans/domain/entities/customer_loan.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class LoansLocalDataSource {
  final AppDatabase database;

  const LoansLocalDataSource(this.database);

  Future<List<CustomerLoan>> getAll() async {
    final db = await database.instance;
    final rows = await db.rawQuery('''
      SELECT
        pr.prestamo_guid, pr.cliente_guid, c.nombre AS cliente_nombre,
        pr.fecha, pr.fecha_vencimiento, pr.monto, pr.concepto, pr.bloqueado,
        COALESCE((
          SELECT SUM(ap.monto_aplicado)
          FROM aplicaciones_prestamo ap
          INNER JOIN cobros_cliente co ON co.cobro_guid = ap.cobro_guid
          WHERE ap.prestamo_guid = pr.prestamo_guid AND co.cancelado = 0
        ), 0) AS abonado
      FROM prestamos_cliente pr
      INNER JOIN clientes c ON c.guid = pr.cliente_guid
      WHERE pr.cancelado = 0
      ORDER BY pr.fecha DESC
    ''');
    return rows
        .map(
          (row) => CustomerLoan(
            guid: row['prestamo_guid']?.toString() ?? '',
            clientGuid: row['cliente_guid']?.toString() ?? '',
            clientName: row['cliente_nombre']?.toString() ?? '',
            date: DateTime.parse(row['fecha'].toString()).toLocal(),
            dueDate: DateTime.parse(
              row['fecha_vencimiento'].toString(),
            ).toLocal(),
            amount: _number(row['monto']),
            paid: _number(row['abonado']),
            concept: row['concepto']?.toString() ?? '',
            blocked: row['bloqueado'] == 1,
          ),
        )
        .toList(growable: false);
  }

  Future<CustomerLoan> create(
    CustomerLoanDraft draft, {
    required String userGuid,
    required String userName,
  }) async {
    if (!draft.amount.isFinite || draft.amount <= 0) {
      throw const LoansLocalException('Captura un monto válido.');
    }
    final db = await database.instance;
    return db.transaction((transaction) async {
      final clients = await transaction.query(
        'clientes',
        columns: const ['nombre'],
        where: 'guid = ? AND deleted_at IS NULL',
        whereArgs: [draft.clientGuid],
        limit: 1,
      );
      if (clients.isEmpty) {
        throw const LoansLocalException('Selecciona un cliente disponible.');
      }
      final branches = await transaction.query(
        'sucursales',
        columns: const ['guid'],
        limit: 1,
      );
      if (branches.isEmpty) {
        throw const LoansLocalException('No existe una sucursal activa.');
      }
      final now = DateTime.now().toUtc();
      final dueDate = draft.dueDate.toUtc();
      if (dueDate.isBefore(DateTime(now.year, now.month, now.day))) {
        throw const LoansLocalException(
          'La fecha de vencimiento no puede ser anterior a hoy.',
        );
      }
      final guid = const Uuid().v4();
      await transaction.insert('prestamos_cliente', {
        'prestamo_guid': guid,
        'sucursal_guid': branches.first['guid'],
        'cliente_guid': draft.clientGuid,
        'fecha': now.toIso8601String(),
        'fecha_vencimiento': dueDate.toIso8601String(),
        'monto': draft.amount,
        'concepto': draft.concept.trim(),
        'usuario_guid': userGuid,
        'usuario_nombre': userName,
        'bloqueado': 0,
        'cancelado': 0,
        'sync': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      return CustomerLoan(
        guid: guid,
        clientGuid: draft.clientGuid,
        clientName: clients.first['nombre']?.toString() ?? '',
        date: now.toLocal(),
        dueDate: dueDate.toLocal(),
        amount: draft.amount,
        paid: 0,
        concept: draft.concept.trim(),
        blocked: false,
      );
    });
  }

  Future<LoanSyncBatch> getPendingSyncBatch({
    bool includeLoans = true,
    bool includeApplications = true,
  }) async {
    final db = await database.instance;
    final loans = includeLoans
        ? await db.query(
            'prestamos_cliente',
            where: 'sync = 0',
            orderBy: 'created_at, prestamo_guid',
          )
        : const <Map<String, Object?>>[];
    final applications = includeApplications
        ? await db.query(
            'aplicaciones_prestamo',
            where: 'sync = 0',
            orderBy: 'created_at, aplicacion_guid',
          )
        : const <Map<String, Object?>>[];
    return LoanSyncBatch(
      loans: loans
          .map(
            (row) => <String, Object?>{
              'prestamoGuid': row['prestamo_guid'],
              'sucursalGuid': row['sucursal_guid'],
              'clienteGuid': row['cliente_guid'],
              'usuarioGuid': row['usuario_guid'],
              'fecha': row['fecha'],
              'fechaVencimiento': row['fecha_vencimiento'],
              'monto': row['monto'],
              'concepto': row['concepto'],
              'bloqueado': row['bloqueado'] == 1,
              'cancelado': row['cancelado'] == 1,
              'createdAt': row['created_at'],
              'updatedAt': row['updated_at'],
            },
          )
          .toList(growable: false),
      applications: applications
          .map(
            (row) => <String, Object?>{
              'aplicacionGuid': row['aplicacion_guid'],
              'cobroGuid': row['cobro_guid'],
              'prestamoGuid': row['prestamo_guid'],
              'montoAplicado': row['monto_aplicado'],
              'createdAt': row['created_at'],
              'updatedAt': row['created_at'],
            },
          )
          .toList(growable: false),
    );
  }

  Future<void> markSyncCompleted(LoanSyncResult result) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      await _markRows(
        transaction,
        table: 'prestamos_cliente',
        guidColumn: 'prestamo_guid',
        guids: result.loans,
      );
      await _markRows(
        transaction,
        table: 'aplicaciones_prestamo',
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
      throw const LoansLocalException(
        'No existe una sucursal activa para recuperar los préstamos.',
      );
    }
    return guid;
  }

  Future<LoansRecoveryResult> mergeCloudSnapshot(LoanSyncBatch snapshot) async {
    final db = await database.instance;
    return db.transaction((transaction) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final clientGuids = await _guidSet(transaction, 'clientes', 'guid');
      final collectionGuids = await _guidSet(
        transaction,
        'cobros_cliente',
        'cobro_guid',
      );
      final loanGuids = await _guidSet(
        transaction,
        'prestamos_cliente',
        'prestamo_guid',
      );
      final pendingLoans = await _pendingGuidSet(
        transaction,
        'prestamos_cliente',
        'prestamo_guid',
      );
      final pendingApplications = await _pendingGuidSet(
        transaction,
        'aplicaciones_prestamo',
        'aplicacion_guid',
      );
      var saved = 0;
      var preserved = 0;
      var omitted = 0;

      for (final row in snapshot.loans) {
        final guid = _text(row, 'prestamoGuid');
        final clientGuid = _text(row, 'clienteGuid');
        if (guid.isEmpty || !clientGuids.contains(clientGuid)) {
          omitted++;
          continue;
        }
        if (pendingLoans.contains(guid)) {
          preserved++;
          continue;
        }
        await _upsertCloudRow(
          transaction,
          table: 'prestamos_cliente',
          guidColumn: 'prestamo_guid',
          guid: guid,
          values: {
            'prestamo_guid': guid,
            'sucursal_guid': _text(row, 'sucursalGuid'),
            'cliente_guid': clientGuid,
            'fecha': _value(row, 'fecha'),
            'fecha_vencimiento': _value(row, 'fechaVencimiento'),
            'monto': _value(row, 'monto'),
            'concepto': _value(row, 'concepto'),
            'usuario_guid': _value(row, 'usuarioGuid'),
            'usuario_nombre': 'Usuario',
            'bloqueado': _boolInt(_value(row, 'bloqueado')),
            'cancelado': _boolInt(_value(row, 'cancelado')),
            'sync': 1,
            'created_at': _value(row, 'createdAt') ?? now,
            'updated_at': _value(row, 'updatedAt') ?? now,
          },
        );
        loanGuids.add(guid);
        saved++;
      }

      for (final row in snapshot.applications) {
        final guid = _text(row, 'aplicacionGuid');
        final loanGuid = _text(row, 'prestamoGuid');
        final collectionGuid = _text(row, 'cobroGuid');
        if (guid.isEmpty ||
            !loanGuids.contains(loanGuid) ||
            !collectionGuids.contains(collectionGuid)) {
          omitted++;
          continue;
        }
        if (pendingApplications.contains(guid)) {
          preserved++;
          continue;
        }
        await _upsertCloudRow(
          transaction,
          table: 'aplicaciones_prestamo',
          guidColumn: 'aplicacion_guid',
          guid: guid,
          values: {
            'aplicacion_guid': guid,
            'cobro_guid': collectionGuid,
            'prestamo_guid': loanGuid,
            'monto_aplicado': _value(row, 'montoAplicado'),
            'created_at': _value(row, 'createdAt') ?? now,
            'sync': 1,
          },
        );
        saved++;
      }
      return LoansRecoveryResult(
        received: snapshot.length,
        saved: saved,
        preservedPending: preserved,
        omittedMissingReferences: omitted,
      );
    });
  }

  Future<void> _markRows(
    DatabaseExecutor database, {
    required String table,
    required String guidColumn,
    required List<String> guids,
  }) async {
    if (guids.isEmpty) return;
    await database.update(
      table,
      const {'sync': 1},
      where: '$guidColumn IN (${List.filled(guids.length, '?').join(',')})',
      whereArgs: guids,
    );
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
    } else {
      final updates = Map<String, Object?>.from(values)..remove(guidColumn);
      await database.update(
        table,
        updates,
        where: '$guidColumn = ?',
        whereArgs: [guid],
      );
    }
  }

  static Object? _value(Map<String, Object?> row, String key) {
    if (row.containsKey(key)) return row[key];
    final pascal = '${key[0].toUpperCase()}${key.substring(1)}';
    return row[pascal];
  }

  static String _text(Map<String, Object?> row, String key) =>
      _value(row, key)?.toString() ?? '';

  static int _boolInt(Object? value) =>
      value == true || value == 1 || value?.toString().toLowerCase() == 'true'
      ? 1
      : 0;
}

double _number(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

class LoansLocalException implements Exception {
  final String message;
  const LoansLocalException(this.message);
  @override
  String toString() => message;
}

final loansLocalDataSourceProvider = Provider<LoansLocalDataSource>((ref) {
  return LoansLocalDataSource(ref.read(appDatabaseProvider));
});
