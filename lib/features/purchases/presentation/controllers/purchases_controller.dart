import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_cart_item.dart';

class PurchaseCartController extends Notifier<List<SaleCartItem>> {
  @override
  List<SaleCartItem> build() => const [];

  bool add(InventoryItem product, double quantity) {
    if (quantity <= 0) return false;
    final index = state.indexWhere(
      (item) => item.product.levelGuid == product.levelGuid,
    );
    if (index < 0) {
      state = [
        ...state,
        SaleCartItem(
          product: product,
          quantity: quantity,
          unitPrice: product.purchasePrice,
        ),
      ];
      return true;
    }
    final updated = [...state];
    updated[index] = updated[index].copyWith(
      quantity: updated[index].quantity + quantity,
    );
    state = updated;
    return true;
  }

  void updateQuantity(String levelGuid, double quantity) {
    if (quantity <= 0) return remove(levelGuid);
    state = [
      for (final item in state)
        if (item.product.levelGuid == levelGuid)
          item.copyWith(quantity: quantity)
        else
          item,
    ];
  }

  void remove(String levelGuid) => state = state
      .where((item) => item.product.levelGuid != levelGuid)
      .toList(growable: false);

  void clear() => state = const [];
}

final purchaseCartControllerProvider =
    NotifierProvider<PurchaseCartController, List<SaleCartItem>>(
      PurchaseCartController.new,
    );

final purchaseCartTotalProvider = Provider<double>(
  (ref) => ref
      .watch(purchaseCartControllerProvider)
      .fold(0, (total, item) => total + item.subtotal),
);

class PurchaseSubmissionController extends Notifier<bool> {
  @override
  bool build() => false;

  void setSubmitting(bool value) => state = value;
}

final purchaseSubmissionControllerProvider =
    NotifierProvider<PurchaseSubmissionController, bool>(
      PurchaseSubmissionController.new,
    );
