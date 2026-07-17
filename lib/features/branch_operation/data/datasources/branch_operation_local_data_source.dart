import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/branch_operation/domain/entities/branch_operation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class BranchOperationLocalDataSource {
  static const activeStatus = 1;
  static const closedStatus = 2;
  final AppDatabase database;

  const BranchOperationLocalDataSource(this.database);

  Future<BranchOperation?> getActive() async {
    final db = await database.instance;
    final rows = await db.query(
      'operaciones_sucursal',
      where: 'estatus_id = ? AND fecha_fin IS NULL AND deleted_at IS NULL',
      whereArgs: const [activeStatus],
      orderBy: 'fecha_inicio DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final financials = await _financialSummary(
      db,
      branchId: (row['sucursal_id'] as num).toInt(),
      start: DateTime.parse(row['fecha_inicio'].toString()),
    );
    return BranchOperation.fromMap({...row, ...financials});
  }

  Future<double> getInventoryValue() async {
    final db = await database.instance;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(existencia * precio_venta), 0) AS total '
      'FROM inventario',
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> getBranchId() async {
    final db = await database.instance;
    final rows = await db.query('sucursales', columns: ['id'], limit: 1);
    if (rows.isEmpty) {
      throw const BranchOperationException(
        'No existe una sucursal activa para iniciar operaciones.',
      );
    }
    return (rows.first['id'] as num).toInt();
  }

  Future<BranchOperation> open({
    required int userId,
    required double initialCashAmount,
    required String? notes,
  }) async {
    final db = await database.instance;
    final existing = await getActive();
    if (existing != null) return existing;
    final now = DateTime.now().toUtc().toIso8601String();
    final guid = const Uuid().v4();
    await db.insert('operaciones_sucursal', {
      'guid': guid,
      'usuario_apertura_id': userId,
      'sucursal_id': await getBranchId(),
      'estatus_id': activeStatus,
      'fecha_inicio': now,
      'valor_inicial_inventario': await getInventoryValue(),
      'monto_inicial_caja': initialCashAmount,
      'observaciones': notes?.trim(),
      'created_at': now,
      'updated_at': now,
    });
    final rows = await db.query(
      'operaciones_sucursal',
      where: 'guid = ?',
      whereArgs: [guid],
      limit: 1,
    );
    return BranchOperation.fromMap(rows.first);
  }

  Future<void> close({
    required String operationGuid,
    required int userId,
  }) async {
    final db = await database.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    final operations = await db.query(
      'operaciones_sucursal',
      where: 'guid = ? AND fecha_fin IS NULL',
      whereArgs: [operationGuid],
      limit: 1,
    );
    if (operations.isEmpty) return;
    final operation = operations.first;
    final financials = await _financialSummary(
      db,
      branchId: (operation['sucursal_id'] as num).toInt(),
      start: DateTime.parse(operation['fecha_inicio'].toString()),
      end: DateTime.parse(now),
    );
    await db.update(
      'operaciones_sucursal',
      {
        'usuario_cierre_id': userId,
        'estatus_id': closedStatus,
        'fecha_fin': now,
        'valor_final_inventario': await getInventoryValue(),
        ...financials,
        'updated_at': now,
      },
      where: 'guid = ? AND fecha_fin IS NULL',
      whereArgs: [operationGuid],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<Map<String, Object?>> _financialSummary(
    Database database, {
    required int branchId,
    required DateTime start,
    DateTime? end,
  }) async {
    final startText = start.toUtc().toIso8601String();
    final endText = end?.toUtc().toIso8601String();
    final dateCondition = endText == null
        ? 'p.fecha >= ?'
        : 'p.fecha >= ? AND p.fecha <= ?';
    final arguments = <Object?>[branchId, startText, ?endText];
    final saleRows = await database.rawQuery('''
      SELECT
        COALESCE(SUM(
          CASE WHEN p.tipo_pedido_guid <> 'c82164a9-616c-4148-80fd-c4702d8a7cca'
            THEN d.cantidad * d.precio_venta * (1 - d.descuento / 100.0)
            ELSE 0 END
        ), 0) AS valor_ventas,
        COALESCE(SUM(
          CASE WHEN p.tipo_pedido_guid = 'c82164a9-616c-4148-80fd-c4702d8a7cca'
            THEN d.cantidad * d.precio_compra
            ELSE 0 END
        ), 0) AS valor_compras,
        COALESCE(SUM(
          CASE WHEN p.tipo_pedido_guid <> 'c82164a9-616c-4148-80fd-c4702d8a7cca'
            THEN d.cantidad * d.precio_venta * (d.descuento / 100.0)
            ELSE 0 END
        ), 0) AS descuentos_aplicados
      FROM pedidos p
      INNER JOIN pedido_detalle d ON d.pedido_guid = p.pedido_guid
      LEFT JOIN estatus e ON e.guid = p.estatus_guid
      INNER JOIN sucursales s
        ON s.guid = p.sucursal_origen_guid AND s.id = ?
      WHERE $dateCondition
        AND LOWER(COALESCE(e.nombre, '')) <> 'cancelado'
    ''', arguments);

    final paymentDateCondition = endText == null
        ? 'pv.fecha_pago >= ?'
        : 'pv.fecha_pago >= ? AND pv.fecha_pago <= ?';
    final paymentRows = await database.rawQuery('''
      SELECT
        COALESCE(SUM(CASE
          WHEN pv.es_credito = 0 AND fp.clave = '01' THEN pv.monto ELSE 0
        END), 0) AS ingreso_efectivo,
        COALESCE(SUM(CASE
          WHEN pv.es_credito = 0 AND fp.clave IN ('04', '28', '29')
            THEN pv.monto ELSE 0
        END), 0) AS ingreso_tarjetas,
        COALESCE(SUM(CASE
          WHEN pv.es_credito = 0 AND fp.clave = '02' THEN pv.monto ELSE 0
        END), 0) AS ingreso_cheques,
        COALESCE(SUM(CASE
          WHEN pv.es_credito = 0 AND fp.clave = '03' THEN pv.monto ELSE 0
        END), 0) AS ingreso_transferencia,
        COALESCE(SUM(CASE
          WHEN pv.es_credito = 0
            AND fp.clave NOT IN ('01', '02', '03', '04', '28', '29')
            THEN pv.monto ELSE 0
        END), 0) AS ingreso_otros,
        COALESCE(SUM(CASE
          WHEN pv.es_credito = 1 THEN pv.monto ELSE 0
        END), 0) AS creditos
      FROM pagos_venta pv
      INNER JOIN pedidos p ON p.pedido_guid = pv.pedido_guid
      INNER JOIN formas_pago fp ON fp.guid = pv.forma_pago_guid
      LEFT JOIN estatus e ON e.guid = p.estatus_guid
      INNER JOIN sucursales s
        ON s.guid = p.sucursal_origen_guid AND s.id = ?
      WHERE $paymentDateCondition
        AND LOWER(COALESCE(e.nombre, '')) <> 'cancelado'
    ''', arguments);

    final sales = saleRows.first;
    final payments = paymentRows.first;
    return {
      'valor_ventas': _decimal(sales['valor_ventas']),
      'valor_compras': _decimal(sales['valor_compras']),
      'descuentos_aplicados': _decimal(sales['descuentos_aplicados']),
      'ingreso_efectivo': _decimal(payments['ingreso_efectivo']),
      'ingreso_tarjetas': _decimal(payments['ingreso_tarjetas']),
      'ingreso_cheques': _decimal(payments['ingreso_cheques']),
      'ingreso_transferencia': _decimal(payments['ingreso_transferencia']),
      'ingreso_otros': _decimal(payments['ingreso_otros']),
      'creditos': _decimal(payments['creditos']),
    };
  }

  double _decimal(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class BranchOperationException implements Exception {
  final String message;
  const BranchOperationException(this.message);
  @override
  String toString() => message;
}

final branchOperationLocalDataSourceProvider =
    Provider<BranchOperationLocalDataSource>((ref) {
      return BranchOperationLocalDataSource(ref.read(appDatabaseProvider));
    });
