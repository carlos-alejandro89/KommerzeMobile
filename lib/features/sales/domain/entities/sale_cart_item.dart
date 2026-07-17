import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';

class SaleCartItem {
  final InventoryItem product;
  final double quantity;
  final double unitPrice;

  const SaleCartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;
  double get discount => subtotal * product.discountPercentage / 100;
  double get total => subtotal - discount;

  SaleCartItem copyWith({double? quantity, double? unitPrice}) => SaleCartItem(
    product: product,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
  );
}
