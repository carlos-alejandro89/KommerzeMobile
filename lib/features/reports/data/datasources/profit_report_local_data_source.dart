import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/reports/domain/entities/profit_report.dart';

class ProfitReportLocalDataSource {
  static const _purchaseGuid = 'c82164a9-616c-4148-80fd-c4702d8a7cca';
  final AppDatabase database;

  const ProfitReportLocalDataSource(this.database);

  Future<List<ProfitOperationSummary>> getOperations(
    DateTime? startDate,
  ) async {
    final db = await database.instance;
    final start = startDate == null
        ? null
        : DateTime(startDate.year, startDate.month, startDate.day).toUtc();
    final dateCondition = start == null ? '' : 'AND o.fecha_inicio >= ?';
    final limitCondition = start == null ? 'LIMIT 6' : '';
    final rows = await db.rawQuery(
      '''
      SELECT o.guid, o.fecha_inicio, o.fecha_fin,
        COALESCE(o.usuario_apertura_nombre, 'Usuario') AS usuario,
        COALESCE(s.nombre_sucursal, s.clave, 'Sucursal') AS sucursal,
        COUNT(DISTINCT CASE WHEN LOWER(COALESCE(e.nombre, '')) <> 'cancelado'
          THEN p.pedido_guid END) AS ventas,
        COALESCE(SUM(d.cantidad * d.precio_venta *
          (1 - d.descuento / 100.0)), 0) AS venta_neta,
        COALESCE(SUM(d.cantidad * d.precio_compra), 0) AS costo
      FROM operaciones_sucursal o
      INNER JOIN sucursales s ON s.id = o.sucursal_id
      LEFT JOIN pedidos p ON p.sucursal_origen_guid = s.guid
        AND p.fecha >= o.fecha_inicio
        AND p.fecha <= COALESCE(o.fecha_fin, ?)
        AND p.tipo_pedido_guid <> ?
      LEFT JOIN estatus e ON e.guid = p.estatus_guid
      LEFT JOIN pedido_detalle d ON d.pedido_guid = p.pedido_guid
        AND LOWER(COALESCE(e.nombre, '')) <> 'cancelado'
      WHERE o.deleted_at IS NULL $dateCondition
      GROUP BY o.guid
      ORDER BY o.fecha_inicio DESC
      $limitCondition
    ''',
      [
        DateTime.now().toUtc().toIso8601String(),
        _purchaseGuid,
        if (start != null) start.toIso8601String(),
      ],
    );
    return rows.map(_summary).toList(growable: false);
  }

  Future<ProfitOperationDetail> getDetail(String operationGuid) async {
    final db = await database.instance;
    final operations = await db.rawQuery(
      '''
      SELECT o.guid, o.fecha_inicio, o.fecha_fin,
        COALESCE(o.usuario_apertura_nombre, 'Usuario') AS usuario,
        COALESCE(s.nombre_sucursal, s.clave, 'Sucursal') AS sucursal,
        COUNT(DISTINCT CASE WHEN LOWER(COALESCE(e.nombre, '')) <> 'cancelado'
          THEN p.pedido_guid END) AS ventas,
        COALESCE(SUM(d.cantidad * d.precio_venta *
          (1 - d.descuento / 100.0)), 0) AS venta_neta,
        COALESCE(SUM(d.cantidad * d.precio_compra), 0) AS costo
      FROM operaciones_sucursal o
      INNER JOIN sucursales s ON s.id = o.sucursal_id
      LEFT JOIN pedidos p ON p.sucursal_origen_guid = s.guid
        AND p.fecha >= o.fecha_inicio AND p.fecha <= COALESCE(o.fecha_fin, ?)
        AND p.tipo_pedido_guid <> ?
      LEFT JOIN estatus e ON e.guid = p.estatus_guid
      LEFT JOIN pedido_detalle d ON d.pedido_guid = p.pedido_guid
        AND LOWER(COALESCE(e.nombre, '')) <> 'cancelado'
      WHERE o.guid = ? AND o.deleted_at IS NULL
      GROUP BY o.guid
    ''',
      [DateTime.now().toUtc().toIso8601String(), _purchaseGuid, operationGuid],
    );
    if (operations.isEmpty) {
      throw StateError('La operación ya no está disponible.');
    }
    final operation = _summary(operations.first);
    final sales = await db.rawQuery(
      '''
      SELECT p.pedido_guid, p.folio, p.fecha,
        COALESCE(c.nombre, 'Público General') AS cliente,
        COALESCE(SUM(d.cantidad * d.precio_venta), 0) AS bruto,
        COALESCE(SUM(d.cantidad * d.precio_venta * d.descuento / 100.0), 0)
          AS descuento,
        COALESCE(SUM(d.cantidad * d.precio_venta *
          (1 - d.descuento / 100.0)), 0) AS neto,
        COALESCE(SUM(d.cantidad * d.precio_compra), 0) AS costo
      FROM pedidos p
      INNER JOIN pedido_detalle d ON d.pedido_guid = p.pedido_guid
      LEFT JOIN clientes c ON c.guid = p.cliente_guid
      LEFT JOIN estatus e ON e.guid = p.estatus_guid
      WHERE p.sucursal_origen_guid = (
        SELECT s.guid FROM operaciones_sucursal o
        INNER JOIN sucursales s ON s.id = o.sucursal_id WHERE o.guid = ?)
        AND p.fecha >= ? AND p.fecha <= COALESCE(?, ?)
        AND p.tipo_pedido_guid <> ?
        AND LOWER(COALESCE(e.nombre, '')) <> 'cancelado'
      GROUP BY p.pedido_guid
      ORDER BY p.fecha DESC
    ''',
      [
        operationGuid,
        operation.startedAt.toUtc().toIso8601String(),
        operation.endedAt?.toUtc().toIso8601String(),
        DateTime.now().toUtc().toIso8601String(),
        _purchaseGuid,
      ],
    );
    return ProfitOperationDetail(
      operation: operation,
      sales: sales
          .map(
            (row) => ProfitSaleItem(
              orderGuid: '${row['pedido_guid']}',
              folio: _int(row['folio']),
              date: DateTime.parse('${row['fecha']}').toLocal(),
              clientName: '${row['cliente']}',
              gross: _double(row['bruto']),
              discount: _double(row['descuento']),
              net: _double(row['neto']),
              cost: _double(row['costo']),
            ),
          )
          .toList(growable: false),
    );
  }

  ProfitOperationSummary _summary(Map<String, Object?> row) =>
      ProfitOperationSummary(
        guid: '${row['guid']}',
        startedAt: DateTime.parse('${row['fecha_inicio']}').toLocal(),
        endedAt: row['fecha_fin'] == null
            ? null
            : DateTime.parse('${row['fecha_fin']}').toLocal(),
        openedBy: '${row['usuario']}',
        branchName: '${row['sucursal']}',
        salesCount: _int(row['ventas']),
        netSales: _double(row['venta_neta']),
        cost: _double(row['costo']),
      );

  static double _double(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

final profitReportLocalDataSourceProvider = Provider(
  (ref) => ProfitReportLocalDataSource(ref.read(appDatabaseProvider)),
);
