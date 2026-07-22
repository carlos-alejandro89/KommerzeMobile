import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_cart_item.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_order.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_payment_draft.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class SalesLocalDataSource {
  static const publicCustomerGuid = '550e8400-e29b-41d4-a716-446655440000';
  static const purchaseOrderTypeGuid = 'c82164a9-616c-4148-80fd-c4702d8a7cca';
  final AppDatabase database;
  const SalesLocalDataSource(this.database);

  Future<SaleOrder> create({
    required String clientGuid,
    required bool isCredit,
    required List<SaleCartItem> items,
    required List<SalePaymentDraft> payments,
    required String statusName,
    String orderTypeName = 'Venta',
  }) async {
    if (items.isEmpty) {
      throw const SalesLocalException('La venta no contiene artículos.');
    }
    final db = await database.instance;
    return db.transaction((transaction) async {
      final branchGuid = await _singleGuid(
        transaction,
        table: 'sucursales',
        error: 'No existe una sucursal activa.',
      );
      final orderTypeGuid = await _singleGuid(
        transaction,
        table: 'tipos_pedido',
        nameColumn: 'nombre',
        name: orderTypeName,
        error: 'Sincroniza el catálogo Tipo de pedido antes de vender.',
      );
      final statusGuid = await _singleGuid(
        transaction,
        table: 'estatus',
        nameColumn: 'nombre',
        name: statusName,
        error: 'Sincroniza el catálogo Estatus antes de vender.',
      );
      final client = await transaction.query(
        'clientes',
        columns: const ['guid', 'dias_credito', 'monto_credito'],
        where: 'guid = ? AND deleted_at IS NULL',
        whereArgs: [clientGuid],
        limit: 1,
      );
      if (client.isEmpty) {
        throw const SalesLocalException(
          'El cliente seleccionado ya no está disponible.',
        );
      }

      final folioRows = await transaction.rawQuery(
        '''
        SELECT COALESCE(MAX(folio), 0) + 1 AS siguiente
        FROM pedidos
        WHERE tipo_pedido_guid = ?
        ''',
        [orderTypeGuid],
      );
      final folio = Sqflite.firstIntValue(folioRows) ?? 1;
      final orderGuid = const Uuid().v4();
      final date = DateTime.now().toUtc();
      final timestamp = date.toIso8601String();

      await transaction.insert('pedidos', {
        'pedido_guid': orderGuid,
        'sucursal_origen_guid': branchGuid,
        'estatus_guid': statusGuid,
        'cliente_guid': clientGuid,
        'tipo_pedido_guid': orderTypeGuid,
        'folio': folio,
        'fecha': timestamp,
        'es_credito': isCredit ? 1 : 0,
        'sync': 1,
        'enviado': 0,
        'created_at': timestamp,
        'updated_at': timestamp,
      });

      final details = <SaleOrderDetail>[];
      final batch = transaction.batch();
      for (final item in items) {
        final inventoryRows = await transaction.query(
          'inventario',
          columns: const ['precio_compra', 'porcentaje_descuento'],
          where: 'nivel_guid = ?',
          whereArgs: [item.product.levelGuid],
          limit: 1,
        );
        if (inventoryRows.isEmpty) {
          throw SalesLocalException(
            'El artículo ${item.product.displayName} ya no existe en inventario.',
          );
        }
        final inventoryRow = inventoryRows.first;
        final purchasePrice = _decimal(inventoryRow['precio_compra']);
        final discountPercentage = _validDiscountPercentage(
          inventoryRow['porcentaje_descuento'],
        );
        final detail = SaleOrderDetail(
          levelGuid: item.product.levelGuid,
          quantity: item.quantity,
          purchasePrice: purchasePrice,
          salePrice: item.unitPrice,
          salePrice2: item.unitPrice,
          discount: discountPercentage,
          additionalInfo: item.product.displayName,
        );
        details.add(detail);
        batch.insert('pedido_detalle', {
          'pedido_guid': orderGuid,
          'nivel_guid': detail.levelGuid,
          'cantidad': detail.quantity,
          'precio_compra': detail.purchasePrice,
          'precio_venta': detail.salePrice,
          'precio_venta_2': detail.salePrice2,
          'descuento': detail.discount,
          'traslado_iva': 0,
          'tasa_iva': 0,
          'retencion_isr': 0,
          'tasa_isr': 0,
          'info_adicional': detail.additionalInfo,
        });
      }
      await batch.commit(noResult: true);

      for (final item in items) {
        final updated = await transaction.rawUpdate(
          '''
          UPDATE inventario
          SET existencia = existencia - ?, updated_at = ?
          WHERE nivel_guid = ? AND existencia >= ?
          ''',
          [item.quantity, timestamp, item.product.levelGuid, item.quantity],
        );
        if (updated != 1) {
          throw SalesLocalException(
            'La existencia de ${item.product.displayName} ya no es suficiente.',
          );
        }
      }

      final saleTotal = details.fold<double>(
        0,
        (sum, detail) =>
            sum +
            (detail.quantity * detail.salePrice * (1 - detail.discount / 100)),
      );
      final actualPayments = applyPaymentsToTotal(
        payments.where((payment) => !payment.isCredit).toList(growable: false),
        saleTotal,
      );
      for (final payment in actualPayments) {
        final paymentFormGuid = await _singleGuid(
          transaction,
          table: 'formas_pago',
          nameColumn: 'clave',
          name: payment.paymentFormKey,
          error:
              'Sincroniza el catálogo Formas de pago antes de registrar la venta.',
        );
        await transaction.insert('pagos_venta', {
          'pago_guid': const Uuid().v4(),
          'forma_pago_guid': paymentFormGuid,
          'pedido_guid': orderGuid,
          'fecha_pago': payment.paidAt.toUtc().toIso8601String(),
          'monto': payment.amount,
          'es_credito': 0,
        });
      }

      final amountPaid = actualPayments.fold<double>(
        0,
        (sum, payment) => sum + payment.amount,
      );
      final receivableAmount = saleTotal - amountPaid;
      if (isCredit && receivableAmount > .001) {
        final usedCreditRows = await transaction.rawQuery(
          '''
          SELECT COALESCE(SUM(MAX(
            cc.importe_original - COALESCE((
              SELECT SUM(ac.monto_aplicado)
              FROM aplicaciones_cobro ac
              INNER JOIN cobros_cliente co ON co.cobro_guid = ac.cobro_guid
              WHERE ac.cuenta_guid = cc.cuenta_guid AND co.cancelado = 0
          ), 0), 0)), 0) AS utilizado
          FROM cuentas_por_cobrar cc
          LEFT JOIN estatus cxe ON cxe.guid = cc.estatus_guid
          WHERE cc.cliente_guid = ?
            AND LOWER(COALESCE(cxe.nombre, '')) <> 'cancelado'
          ''',
          [clientGuid],
        );
        final creditLimit = _decimal(client.first['monto_credito']);
        final availableCredit =
            creditLimit - _decimal(usedCreditRows.first['utilizado']);
        if (receivableAmount - availableCredit > .001) {
          throw SalesLocalException(
            'El saldo a crédito supera el disponible del cliente.',
          );
        }
        final creditDays = _integer(client.first['dias_credito']);
        final dueAt = date.add(Duration(days: creditDays));
        final receivableStatusGuid = await _singleGuid(
          transaction,
          table: 'estatus',
          nameColumn: 'nombre',
          name: creditDays <= 0 ? 'Vencida' : 'Pendiente',
          error:
              'Sincroniza el catálogo Estatus antes de registrar una venta a crédito.',
        );
        await transaction.insert('cuentas_por_cobrar', {
          'cuenta_guid': const Uuid().v4(),
          'cliente_guid': clientGuid,
          'pedido_guid': orderGuid,
          'importe_original': receivableAmount,
          'fecha_emision': timestamp,
          'fecha_vencimiento': dueAt.toIso8601String(),
          'estatus_guid': receivableStatusGuid,
          'bloqueada': 0,
          'sync': 0,
          'created_at': timestamp,
          'updated_at': timestamp,
        });
      }

      return SaleOrder(
        branchOriginGuid: branchGuid,
        orderGuid: orderGuid,
        statusGuid: statusGuid,
        clientGuid: clientGuid,
        orderTypeGuid: orderTypeGuid,
        folio: folio,
        date: date,
        isCredit: isCredit,
        sync: true,
        sent: false,
        details: details,
      );
    });
  }

  Future<List<SaleOrder>> getPending() async {
    final db = await database.instance;
    final orders = await db.query(
      'pedidos',
      where: 'enviado = ?',
      whereArgs: const [0],
      orderBy: 'fecha ASC',
    );
    final result = <SaleOrder>[];
    for (final row in orders) {
      final orderGuid = row['pedido_guid']?.toString() ?? '';
      final detailRows = await db.query(
        'pedido_detalle',
        where: 'pedido_guid = ?',
        whereArgs: [orderGuid],
        orderBy: 'id ASC',
      );
      result.add(
        SaleOrder(
          branchOriginGuid: row['sucursal_origen_guid']?.toString() ?? '',
          orderGuid: orderGuid,
          statusGuid: row['estatus_guid']?.toString() ?? '',
          clientGuid: row['cliente_guid']?.toString() ?? '',
          orderTypeGuid: row['tipo_pedido_guid']?.toString() ?? '',
          folio: _integer(row['folio']),
          date: DateTime.parse(row['fecha'].toString()),
          isCredit: row['es_credito'] == 1,
          sync: row['sync'] == 1,
          sent: row['enviado'] == 1,
          details: detailRows
              .map(
                (detail) => SaleOrderDetail(
                  levelGuid: detail['nivel_guid']?.toString() ?? '',
                  quantity: _decimal(detail['cantidad']),
                  purchasePrice: _decimal(detail['precio_compra']),
                  salePrice: _decimal(detail['precio_venta']),
                  salePrice2: _decimal(detail['precio_venta_2']),
                  discount: _decimal(detail['descuento']),
                  vatTransfer: _decimal(detail['traslado_iva']),
                  vatRate: _decimal(detail['tasa_iva']),
                  incomeTaxWithholding: _decimal(detail['retencion_isr']),
                  incomeTaxRate: _decimal(detail['tasa_isr']),
                  additionalInfo: detail['info_adicional']?.toString() ?? '',
                ),
              )
              .toList(growable: false),
        ),
      );
    }
    return result;
  }

  Future<SaleOrder> createPurchase(List<SaleCartItem> items) async {
    if (items.isEmpty) {
      throw const SalesLocalException('La compra no contiene artículos.');
    }
    final db = await database.instance;
    return db.transaction((transaction) async {
      final branchGuid = await _singleGuid(
        transaction,
        table: 'sucursales',
        error: 'No existe una sucursal activa.',
      );
      final statusGuid = await _singleGuid(
        transaction,
        table: 'estatus',
        nameColumn: 'nombre',
        name: 'Confirmado',
        error: 'Sincroniza el catálogo Estatus antes de comprar.',
      );
      final folioRows = await transaction.rawQuery(
        '''
        SELECT COALESCE(MAX(folio), 0) + 1 AS siguiente
        FROM pedidos
        WHERE tipo_pedido_guid = ?
        ''',
        [purchaseOrderTypeGuid],
      );
      final folio = Sqflite.firstIntValue(folioRows) ?? 1;
      final orderGuid = const Uuid().v4();
      final date = DateTime.now().toUtc();
      final timestamp = date.toIso8601String();

      await transaction.insert('pedidos', {
        'pedido_guid': orderGuid,
        'sucursal_origen_guid': branchGuid,
        'estatus_guid': statusGuid,
        'cliente_guid': publicCustomerGuid,
        'tipo_pedido_guid': purchaseOrderTypeGuid,
        'folio': folio,
        'fecha': timestamp,
        'es_credito': 0,
        'sync': 1,
        'enviado': 0,
        'created_at': timestamp,
        'updated_at': timestamp,
      });

      final details = <SaleOrderDetail>[];
      for (final item in items) {
        final detail = SaleOrderDetail(
          levelGuid: item.product.levelGuid,
          quantity: item.quantity,
          purchasePrice: item.product.purchasePrice,
          salePrice: item.product.salePrice,
          salePrice2: item.product.salePrice,
          discount: 0,
          additionalInfo: item.product.displayName,
        );
        details.add(detail);
        await transaction.insert('pedido_detalle', {
          'pedido_guid': orderGuid,
          'nivel_guid': detail.levelGuid,
          'cantidad': detail.quantity,
          'precio_compra': detail.purchasePrice,
          'precio_venta': detail.salePrice,
          'precio_venta_2': detail.salePrice2,
          'descuento': 0,
          'traslado_iva': 0,
          'tasa_iva': 0,
          'retencion_isr': 0,
          'tasa_isr': 0,
          'info_adicional': detail.additionalInfo,
        });
        await transaction.rawUpdate(
          '''
          UPDATE inventario
          SET existencia = existencia + ?, updated_at = ?
          WHERE nivel_guid = ?
          ''',
          [detail.quantity, timestamp, detail.levelGuid],
        );
      }

      return SaleOrder(
        branchOriginGuid: branchGuid,
        orderGuid: orderGuid,
        statusGuid: statusGuid,
        clientGuid: publicCustomerGuid,
        orderTypeGuid: purchaseOrderTypeGuid,
        folio: folio,
        date: date,
        isCredit: false,
        sync: true,
        sent: false,
        details: details,
      );
    });
  }

  Future<void> markAsSent(String orderGuid) async {
    final db = await database.instance;
    final updated = await db.update(
      'pedidos',
      {
        'enviado': 1,
        'sync': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'pedido_guid = ?',
      whereArgs: [orderGuid],
    );
    if (updated != 1) {
      throw const SalesLocalException(
        'No fue posible actualizar el estado local de la venta.',
      );
    }
  }

  Future<String> _singleGuid(
    DatabaseExecutor database, {
    required String table,
    String? nameColumn,
    String? name,
    required String error,
  }) async {
    final rows = await database.query(
      table,
      columns: const ['guid'],
      where: nameColumn == null ? null : '$nameColumn = ? COLLATE NOCASE',
      whereArgs: nameColumn == null ? null : [name],
      limit: 1,
    );
    if (rows.isEmpty) throw SalesLocalException(error);
    final guid = rows.first['guid']?.toString() ?? '';
    if (guid.isEmpty) throw SalesLocalException(error);
    return guid;
  }

  double _decimal(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  double _validDiscountPercentage(Object? value) {
    final percentage = _decimal(value);
    if (!percentage.isFinite || percentage < 0 || percentage > 100) return 0;
    return percentage;
  }

  int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

class SalesLocalException implements Exception {
  final String message;
  const SalesLocalException(this.message);
  @override
  String toString() => message;
}

final salesLocalDataSourceProvider = Provider<SalesLocalDataSource>(
  (ref) => SalesLocalDataSource(ref.read(appDatabaseProvider)),
);
