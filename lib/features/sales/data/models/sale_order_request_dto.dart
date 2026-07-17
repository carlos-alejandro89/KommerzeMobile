import 'package:kommerze_mobile/features/sales/domain/entities/sale_order.dart';

class SaleOrderRequestDto {
  final SaleOrder order;
  const SaleOrderRequestDto(this.order);

  Map<String, dynamic> toJson() => {
    'sucursalOrigenGuid': order.branchOriginGuid,
    'pedidoGuid': order.orderGuid,
    'estatusGuid': order.statusGuid,
    'clienteGuid': order.clientGuid,
    'tipoPedidoGuid': order.orderTypeGuid,
    'folio': order.folio,
    'fecha': order.date.toUtc().toIso8601String(),
    'esCredito': order.isCredit,
    'sync': order.sync,
    'pedidoDetalle': [
      for (final detail in order.details)
        {
          'nivelGuid': detail.levelGuid,
          'cantidad': detail.quantity,
          'precioCompra': detail.purchasePrice,
          'precioVenta': detail.salePrice,
          'precioVenta2': detail.salePrice2,
          'descuento': detail.discount,
          'trasladoIVA': detail.vatTransfer,
          'tasaIVA': detail.vatRate,
          'retencionISR': detail.incomeTaxWithholding,
          'tasaISR': detail.incomeTaxRate,
          'infoAdicional': detail.additionalInfo,
        },
    ],
  };
}
