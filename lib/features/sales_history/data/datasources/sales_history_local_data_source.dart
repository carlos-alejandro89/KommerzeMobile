import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_history_item.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_detail.dart';

class SalesHistoryLocalDataSource {
  final AppDatabase database;
  const SalesHistoryLocalDataSource(this.database);

  Future<List<SaleHistoryItem>> getAll({int? limit}) async {
    final db = await database.instance;
    final rows = await db.rawQuery('''
      SELECT
        p.pedido_guid,
        p.folio,
        p.fecha,
        p.es_credito,
        p.enviado,
        COALESCE(c.nombre, 'Cliente no disponible') AS cliente_nombre,
        COALESCE(e.nombre, 'Sin estatus') AS estatus_nombre,
        COALESCE(t.nombre, 'Venta') AS tipo_pedido_nombre,
        COALESCE(d.total, 0) AS total,
        COALESCE(d.unidades, 0) AS unidades,
        COALESCE(pg.formas_pago, '') AS formas_pago,
        COALESCE(pg.monto_cobrado, 0) + COALESCE(ca.monto_cobrado, 0)
          AS monto_cobrado,
        CASE WHEN cx.pedido_guid IS NOT NULL THEN COALESCE(cx.saldo_credito, 0)
          ELSE COALESCE(pg.monto_credito, 0) END AS monto_credito
      FROM pedidos p
      LEFT JOIN clientes c ON c.guid = p.cliente_guid
      LEFT JOIN estatus e ON e.guid = p.estatus_guid
      LEFT JOIN tipos_pedido t ON t.guid = p.tipo_pedido_guid
      LEFT JOIN (
        SELECT
          pedido_guid,
          SUM(cantidad * precio_venta * (1 - descuento / 100.0)) AS total,
          SUM(cantidad) AS unidades
        FROM pedido_detalle
        GROUP BY pedido_guid
      ) d ON d.pedido_guid = p.pedido_guid
      LEFT JOIN (
        SELECT
          payment_rows.pedido_guid,
          GROUP_CONCAT(payment_rows.forma, '|||') AS formas_pago,
          SUM(payment_rows.monto_cobrado) AS monto_cobrado,
          SUM(payment_rows.monto_credito) AS monto_credito
        FROM (
          SELECT
            pv.pedido_guid,
            fp.clave || '::' || fp.descripcion AS forma,
            SUM(CASE WHEN pv.es_credito = 0 THEN pv.monto ELSE 0 END)
              AS monto_cobrado,
            SUM(CASE WHEN pv.es_credito = 1 THEN pv.monto ELSE 0 END)
              AS monto_credito
          FROM pagos_venta pv
          INNER JOIN formas_pago fp ON fp.guid = pv.forma_pago_guid
          GROUP BY pv.pedido_guid, fp.clave, fp.descripcion
        ) payment_rows
        GROUP BY payment_rows.pedido_guid
      ) pg ON pg.pedido_guid = p.pedido_guid
      LEFT JOIN (
        SELECT cc.pedido_guid, SUM(ac.monto_aplicado) AS monto_cobrado
        FROM cuentas_por_cobrar cc
        INNER JOIN aplicaciones_cobro ac ON ac.cuenta_guid = cc.cuenta_guid
        INNER JOIN cobros_cliente co ON co.cobro_guid = ac.cobro_guid
        WHERE co.cancelado = 0
        GROUP BY cc.pedido_guid
      ) ca ON ca.pedido_guid = p.pedido_guid
      LEFT JOIN (
        SELECT
          cc.pedido_guid,
          MAX(cc.importe_original - COALESCE(SUM(CASE
            WHEN co.cancelado = 0 THEN ac.monto_aplicado ELSE 0 END), 0), 0)
            AS saldo_credito
        FROM cuentas_por_cobrar cc
        LEFT JOIN aplicaciones_cobro ac ON ac.cuenta_guid = cc.cuenta_guid
        LEFT JOIN cobros_cliente co ON co.cobro_guid = ac.cobro_guid
        LEFT JOIN estatus cxe ON cxe.guid = cc.estatus_guid
        WHERE LOWER(COALESCE(cxe.nombre, '')) <> 'cancelado'
        GROUP BY cc.pedido_guid, cc.importe_original
      ) cx ON cx.pedido_guid = p.pedido_guid
      WHERE p.tipo_pedido_guid <> 'c82164a9-616c-4148-80fd-c4702d8a7cca'
      ORDER BY p.fecha DESC
      ${limit == null ? '' : 'LIMIT ?'}
    ''', limit == null ? null : [limit]);
    return rows.map(_fromMap).toList(growable: false);
  }

  Future<SaleDetail?> getDetail(String orderGuid) async {
    final db = await database.instance;
    final orders = await db.rawQuery(
      '''
      SELECT
        p.pedido_guid, p.folio, p.fecha, p.es_credito, p.enviado,
        COALESCE(c.nombre, 'Cliente no disponible') AS cliente_nombre,
        COALESCE(c.rfc, '') AS cliente_rfc,
        COALESCE(e.nombre, 'Sin estatus') AS estatus_nombre,
        COALESCE(t.nombre, 'Venta') AS tipo_pedido_nombre,
        COALESCE(s.nombre_sucursal, 'Sucursal') AS sucursal_nombre
      FROM pedidos p
      LEFT JOIN clientes c ON c.guid = p.cliente_guid
      LEFT JOIN estatus e ON e.guid = p.estatus_guid
      LEFT JOIN tipos_pedido t ON t.guid = p.tipo_pedido_guid
      LEFT JOIN sucursales s ON s.guid = p.sucursal_origen_guid
      WHERE p.pedido_guid = ?
      LIMIT 1
    ''',
      [orderGuid],
    );
    if (orders.isEmpty) return null;
    final itemRows = await db.rawQuery(
      '''
      SELECT
        d.nivel_guid, d.cantidad, d.precio_venta, d.descuento,
        COALESCE(i.codigo, '') AS codigo,
        COALESCE(i.descripcion, d.info_adicional, 'Artículo') AS nombre,
        COALESCE(i.codigo_barras, '') AS codigo_barras,
        COALESCE(i.img_referencia, '') AS img_referencia
      FROM pedido_detalle d
      LEFT JOIN inventario i ON i.nivel_guid = d.nivel_guid
      WHERE d.pedido_guid = ?
      ORDER BY d.id
    ''',
      [orderGuid],
    );
    final paymentRows = await db.rawQuery(
      '''
      SELECT * FROM (
        SELECT
          pv.pago_guid, pv.fecha_pago, pv.monto, pv.es_credito,
          COALESCE(fp.clave, '') AS forma_clave,
          COALESCE(fp.descripcion, 'Forma de pago') AS forma_descripcion
        FROM pagos_venta pv
        LEFT JOIN formas_pago fp ON fp.guid = pv.forma_pago_guid
        WHERE pv.pedido_guid = ?
        UNION ALL
        SELECT
          ac.aplicacion_guid AS pago_guid,
          co.fecha AS fecha_pago,
          ac.monto_aplicado AS monto,
          0 AS es_credito,
          'COB' AS forma_clave,
          'COBRANZA · ' || COALESCE((
            SELECT CASE WHEN COUNT(*) > 1 THEN 'MULTIPAGO'
              ELSE MAX(fp2.descripcion) END
            FROM cobro_formas_pago cfp2
            INNER JOIN formas_pago fp2 ON fp2.guid = cfp2.forma_pago_guid
            WHERE cfp2.cobro_guid = co.cobro_guid
          ), 'PAGO') AS forma_descripcion
        FROM cuentas_por_cobrar cc
        INNER JOIN aplicaciones_cobro ac ON ac.cuenta_guid = cc.cuenta_guid
        INNER JOIN cobros_cliente co ON co.cobro_guid = ac.cobro_guid
        WHERE cc.pedido_guid = ? AND co.cancelado = 0
      )
      ORDER BY fecha_pago
    ''',
      [orderGuid, orderGuid],
    );
    final order = orders.first;
    return SaleDetail(
      orderGuid: order['pedido_guid']?.toString() ?? '',
      folio: _integer(order['folio']),
      date: DateTime.parse(order['fecha'].toString()).toLocal(),
      isCredit: order['es_credito'] == 1,
      sent: order['enviado'] == 1,
      clientName: order['cliente_nombre']?.toString() ?? '',
      clientRfc: order['cliente_rfc']?.toString() ?? '',
      statusName: order['estatus_nombre']?.toString() ?? '',
      orderTypeName: order['tipo_pedido_nombre']?.toString() ?? '',
      branchName: order['sucursal_nombre']?.toString() ?? '',
      items: itemRows
          .map(
            (row) => SaleDetailItem(
              levelGuid: row['nivel_guid']?.toString() ?? '',
              code: row['codigo']?.toString() ?? '',
              name: row['nombre']?.toString() ?? '',
              barcode: row['codigo_barras']?.toString() ?? '',
              imagePath: row['img_referencia']?.toString() ?? '',
              quantity: _decimal(row['cantidad']),
              unitPrice: _decimal(row['precio_venta']),
              discountPercentage: _decimal(row['descuento']),
            ),
          )
          .toList(growable: false),
      payments: paymentRows
          .map(
            (row) => SaleDetailPayment(
              guid: row['pago_guid']?.toString() ?? '',
              paymentFormKey: row['forma_clave']?.toString() ?? '',
              paymentFormDescription:
                  row['forma_descripcion']?.toString() ?? '',
              paidAt: DateTime.parse(row['fecha_pago'].toString()).toLocal(),
              amount: _decimal(row['monto']),
              isCredit: row['es_credito'] == 1,
            ),
          )
          .toList(growable: false),
    );
  }

  SaleHistoryItem _fromMap(Map<String, Object?> row) => SaleHistoryItem(
    orderGuid: row['pedido_guid']?.toString() ?? '',
    folio: _integer(row['folio']),
    date: DateTime.parse(row['fecha'].toString()).toLocal(),
    isCredit: row['es_credito'] == 1,
    sent: row['enviado'] == 1,
    clientName: row['cliente_nombre']?.toString() ?? '',
    statusName: row['estatus_nombre']?.toString() ?? '',
    orderTypeName: row['tipo_pedido_nombre']?.toString() ?? '',
    total: _decimal(row['total']),
    units: _decimal(row['unidades']),
    collectedAmount: _decimal(row['monto_cobrado']),
    creditAmount: _decimal(row['monto_credito']),
    paymentForms: _paymentForms(row['formas_pago']),
  );

  List<SalePaymentIdentifier> _paymentForms(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return const [];
    return text
        .split('|||')
        .map((entry) {
          final separator = entry.indexOf('::');
          return SalePaymentIdentifier(
            key: separator < 0 ? entry : entry.substring(0, separator),
            description: separator < 0 ? entry : entry.substring(separator + 2),
          );
        })
        .toList(growable: false);
  }

  double _decimal(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

final salesHistoryLocalDataSourceProvider =
    Provider<SalesHistoryLocalDataSource>(
      (ref) => SalesHistoryLocalDataSource(ref.read(appDatabaseProvider)),
    );
