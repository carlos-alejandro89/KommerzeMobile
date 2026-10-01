import 'package:kommerze_mobile/features/checkout/domain/entities/sale_payment.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_cart_item.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_order.dart';

class SaleReceipt {
  final SaleOrder order;
  final Client client;
  final List<SaleCartItem> items;
  final List<SalePayment> payments;

  const SaleReceipt({
    required this.order,
    required this.client,
    required this.items,
    required this.payments,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get discount => items.fold(0, (sum, item) => sum + item.discount);
  double get total => items.fold(0, (sum, item) => sum + item.total);
  double get paid => payments.fold(0, (sum, payment) => sum + payment.amount);
  String get folio => 'VTA-${order.folio.toString().padLeft(6, '0')}';
}
