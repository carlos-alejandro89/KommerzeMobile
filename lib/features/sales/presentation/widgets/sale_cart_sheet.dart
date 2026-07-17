import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/product_image.dart';
import 'package:kommerze_mobile/features/branch_operation/presentation/controllers/branch_operation_controller.dart';
import 'package:kommerze_mobile/features/inventory/presentation/controllers/inventory_controller.dart';
import 'package:kommerze_mobile/features/purchases/presentation/controllers/purchases_controller.dart';
import 'package:kommerze_mobile/features/sales/data/repositories/sales_repository.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_cart_item.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_order.dart';
import 'package:kommerze_mobile/features/sales/presentation/controllers/sales_controller.dart';

class SaleCartSheet extends ConsumerWidget {
  final bool purchaseMode;
  const SaleCartSheet({super.key, this.purchaseMode = false});

  static Future<void> show(BuildContext context, {bool purchaseMode = false}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SaleCartSheet(purchaseMode: purchaseMode),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = purchaseMode
        ? ref.watch(purchaseCartControllerProvider)
        : ref.watch(saleCartControllerProvider);
    final total = purchaseMode
        ? ref.watch(purchaseCartTotalProvider)
        : ref.watch(saleCartTotalProvider);
    final purchaseSubmitting = ref.watch(purchaseSubmissionControllerProvider);
    return DraggableScrollableSheet(
      initialChildSize: .72,
      minChildSize: .45,
      maxChildSize: .94,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F9FD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8E0ED),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      purchaseMode ? 'Compra actual' : 'Venta actual',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: () => purchaseMode
                          ? ref
                                .read(purchaseCartControllerProvider.notifier)
                                .clear()
                          : ref
                                .read(saleCartControllerProvider.notifier)
                                .clear(),
                      child: const Text('Vaciar'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: AppColors.textGrey,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Aún no hay artículos',
                            style: TextStyle(color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        void updateQuantity(double quantity) {
                          if (purchaseMode) {
                            ref
                                .read(purchaseCartControllerProvider.notifier)
                                .updateQuantity(
                                  item.product.levelGuid,
                                  quantity,
                                );
                          } else {
                            ref
                                .read(saleCartControllerProvider.notifier)
                                .updateQuantity(
                                  item.product.levelGuid,
                                  quantity,
                                );
                          }
                        }

                        void removeItem() {
                          if (purchaseMode) {
                            ref
                                .read(purchaseCartControllerProvider.notifier)
                                .remove(item.product.levelGuid);
                          } else {
                            ref
                                .read(saleCartControllerProvider.notifier)
                                .remove(item.product.levelGuid);
                          }
                        }

                        final lineTotal = purchaseMode
                            ? item.subtotal
                            : item.total;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE7ECF5)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 58,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(
                                        color: AppColors.borderGrey,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: ProductImage(
                                        imagePath: item.product.imagePath,
                                        iconSize: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.displayName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.navy,
                                            fontSize: 14,
                                            height: 1.2,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.product.code,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textGrey,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Precio unitario  ·  \$${item.unitPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: AppColors.primaryBlue,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar artículo',
                                    onPressed: removeItem,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 34,
                                      height: 34,
                                    ),
                                    padding: EdgeInsets.zero,
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.errorSoft,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 11),
                                child: Divider(height: 1),
                              ),
                              Row(
                                children: [
                                  const Text(
                                    'Cantidad',
                                    style: TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySurface,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              updateQuantity(item.quantity - 1),
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                width: 32,
                                                height: 32,
                                              ),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                            Icons.remove_rounded,
                                            size: 18,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 34,
                                          child: Text(
                                            _number(item.quantity),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppColors.navy,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed:
                                              purchaseMode ||
                                                  item.quantity <
                                                      item.product.stock
                                              ? () => updateQuantity(
                                                  item.quantity + 1,
                                                )
                                              : null,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                                width: 32,
                                                height: 32,
                                              ),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Importe',
                                        style: TextStyle(
                                          color: AppColors.textGrey,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        '\$${lineTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppColors.navy,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE7ECF5))),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: items.isEmpty || purchaseSubmitting
                            ? null
                            : purchaseMode
                            ? () => _registerPurchase(context, ref)
                            : () {
                                final router = GoRouter.of(context);
                                Navigator.pop(context);
                                router.push(AppConstants.checkoutScreenRoute);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: purchaseMode && purchaseSubmitting
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Generando compra...'),
                                ],
                              )
                            : Text(
                                purchaseMode
                                    ? 'Registrar compra'
                                    : 'Continuar al cobro',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerPurchase(BuildContext context, WidgetRef ref) async {
    final items = ref.read(purchaseCartControllerProvider);
    if (items.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar compra'),
        content: Text(
          'Se agregarán ${items.length} artículos al inventario por un total de '
          '\$${ref.read(purchaseCartTotalProvider).toStringAsFixed(2)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final submission = ref.read(purchaseSubmissionControllerProvider.notifier);
    if (ref.read(purchaseSubmissionControllerProvider)) return;
    submission.setSubmitting(true);
    try {
      await _performRegisterPurchase(context, ref, items);
    } finally {
      submission.setSubmitting(false);
    }
  }

  Future<void> _performRegisterPurchase(
    BuildContext context,
    WidgetRef ref,
    List<SaleCartItem> items,
  ) async {
    late final SaleOrder order;
    try {
      order = await ref.read(salesRepositoryProvider).savePurchase(items);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    var synced = false;
    try {
      final report = await ref.read(salesRepositoryProvider).syncPending();
      synced = report.isSynchronized(order.orderGuid);
    } catch (_) {
      // La compra permanece en SQLite para el siguiente intento.
    }
    if (!context.mounted) return;
    ref.read(purchaseCartControllerProvider.notifier).clear();
    ref.invalidate(inventoryControllerProvider);
    ref.invalidate(salesCatalogControllerProvider);
    ref.invalidate(branchOperationControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Compra ${order.folio} registrada y sincronizada.'
              : 'Compra ${order.folio} guardada y pendiente de sincronización.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: synced ? AppColors.success : AppColors.warning,
      ),
    );
  }
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
