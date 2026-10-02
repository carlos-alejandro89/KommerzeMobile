import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/layout/app_breakpoints.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/core/widgets/product_image.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:kommerze_mobile/features/purchases/presentation/controllers/purchases_controller.dart';
import 'package:kommerze_mobile/features/checkout/presentation/controllers/checkout_controller.dart';
import 'package:kommerze_mobile/features/clients/data/repositories/clients_repository.dart';
import 'package:kommerze_mobile/features/sales/presentation/controllers/sales_controller.dart';
import 'package:kommerze_mobile/features/sales/presentation/screens/barcode_scanner_screen.dart';
import 'package:kommerze_mobile/features/sales/presentation/widgets/product_selection_sheet.dart';
import 'package:kommerze_mobile/features/sales/presentation/widgets/sale_cart_sheet.dart';

class SalesScreen extends ConsumerStatefulWidget {
  final bool purchaseMode;
  const SalesScreen({super.key, this.purchaseMode = false});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  bool _continuousScanner = false;
  bool _scannerOpen = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 420) {
      ref.read(salesCatalogControllerProvider.notifier).loadMore();
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 320),
      () => ref.read(salesCatalogControllerProvider.notifier).search(value),
    );
  }

  Future<bool> _resolveBarcode(String code) async {
    if (code.trim().isEmpty) return false;
    final product = await ref
        .read(salesCatalogControllerProvider.notifier)
        .findByBarcode(code);
    if (!mounted) return false;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No encontramos un artículo con ese código.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    final added = await _selectProduct(product);
    _search.clear();
    return added;
  }

  Future<void> _toggleContinuousScanner() async {
    setState(() => _continuousScanner = !_continuousScanner);
    if (_continuousScanner) await _scanCamera(continuous: true);
  }

  Future<void> _scanCamera({bool continuous = false}) async {
    if (_scannerOpen) return;
    _scannerOpen = true;
    try {
      while (mounted && (!continuous || _continuousScanner)) {
        if (!mounted) break;
        final code = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => BarcodeScannerScreen(continuousMode: continuous),
          ),
        );
        if (!mounted || code == null) break;
        if (code == BarcodeScannerScreen.stopContinuousResult) {
          setState(() => _continuousScanner = false);
          break;
        }
        final added = await _resolveBarcode(code);
        if (!continuous || !added) break;
      }
    } finally {
      _scannerOpen = false;
    }
  }

  Future<bool> _selectProduct(InventoryItem product) async {
    final quantity = await ProductSelectionSheet.show(
      context,
      product,
      purchaseMode: widget.purchaseMode,
    );
    if (quantity == null || !mounted) return false;
    final added = widget.purchaseMode
        ? ref
              .read(purchaseCartControllerProvider.notifier)
              .add(product, quantity)
        : ref.read(saleCartControllerProvider.notifier).add(product, quantity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Artículo agregado a la ${widget.purchaseMode ? 'compra' : 'venta'}.'
              : 'La cantidad acumulada supera la existencia.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: added
            ? const Color(0xFF087A45)
            : const Color(0xFFD92D20),
      ),
    );
    return added;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(salesCatalogControllerProvider);
    final cart = widget.purchaseMode
        ? ref.watch(purchaseCartControllerProvider)
        : ref.watch(saleCartControllerProvider);
    final total = widget.purchaseMode
        ? ref.watch(purchaseCartTotalProvider)
        : ref.watch(saleCartTotalProvider);
    final tabletLandscape = AppBreakpoints.isTabletLandscape(context);
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: widget.purchaseMode ? 'Compras' : 'Ventas',
            subtitle: widget.purchaseMode
                ? 'Registra artículos recibidos'
                : 'Busca y agrega artículos',
            height: 166,
            showBackButton: true,
            actions: [
              IconButton(
                onPressed: _toggleContinuousScanner,
                tooltip: _continuousScanner
                    ? 'Desactivar escaneo continuo'
                    : 'Activar escaneo continuo',
                icon: Icon(
                  _continuousScanner
                      ? Icons.videocam_off_rounded
                      : Icons.qr_code_scanner_rounded,
                  color: _continuousScanner
                      ? const Color(0xFF72E1B4)
                      : Colors.white,
                ),
              ),
            ],
            content: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: _onSearch,
              onSubmitted: _resolveBarcode,
              decoration: InputDecoration(
                hintText: 'Código, descripción o código de barras',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primaryBlue,
                ),
                suffixIcon: widget.purchaseMode
                    ? IconButton(
                        onPressed: () => _scanCamera(),
                        icon: const Icon(
                          Icons.document_scanner_outlined,
                          color: AppColors.primaryBlue,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: catalog.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No fue posible cargar el inventario.\n$error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    data: (state) => state.items.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron artículos.',
                              style: TextStyle(color: AppColors.textGrey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => ref
                                .read(salesCatalogControllerProvider.notifier)
                                .search(state.query),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final columns =
                                    tabletLandscape &&
                                        constraints.maxWidth > 720
                                    ? 2
                                    : 1;
                                return GridView.builder(
                                  controller: _scroll,
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    14,
                                    14,
                                    100,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        mainAxisExtent: 128,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 0,
                                      ),
                                  itemCount:
                                      state.items.length +
                                      (state.loadingMore ? 1 : 0),
                                  itemBuilder: (context, index) =>
                                      index == state.items.length
                                      ? const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      : _ProductCard(
                                          product: state.items[index],
                                          purchaseMode: widget.purchaseMode,
                                          onTap: () => _selectProduct(
                                            state.items[index],
                                          ),
                                        ),
                                );
                              },
                            ),
                          ),
                  ),
                ),
                if (tabletLandscape) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 390,
                    child: _TabletCartPanel(purchaseMode: widget.purchaseMode),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: tabletLandscape
          ? null
          : FloatingActionButton.extended(
              onPressed: () => SaleCartSheet.show(
                context,
                purchaseMode: widget.purchaseMode,
              ),
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(
                '${cart.fold<double>(0, (sum, item) => sum + item.quantity).toStringAsFixed(0)}  •  \$${total.toStringAsFixed(2)}',
              ),
            ),
    );
  }
}

class _TabletCartPanel extends ConsumerWidget {
  final bool purchaseMode;
  const _TabletCartPanel({required this.purchaseMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = purchaseMode
        ? ref.watch(purchaseCartControllerProvider)
        : ref.watch(saleCartControllerProvider);
    final total = purchaseMode
        ? ref.watch(purchaseCartTotalProvider)
        : ref.watch(saleCartTotalProvider);
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    purchaseMode ? 'Compra actual' : 'Venta actual',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
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
                        : ref.read(saleCartControllerProvider.notifier).clear(),
                    child: const Text('Vaciar'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? const _EmptyTabletCart()
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      void update(double quantity) => purchaseMode
                          ? ref
                                .read(purchaseCartControllerProvider.notifier)
                                .updateQuantity(
                                  item.product.levelGuid,
                                  quantity,
                                )
                          : ref
                                .read(saleCartControllerProvider.notifier)
                                .updateQuantity(
                                  item.product.levelGuid,
                                  quantity,
                                );
                      void remove() => purchaseMode
                          ? ref
                                .read(purchaseCartControllerProvider.notifier)
                                .remove(item.product.levelGuid)
                          : ref
                                .read(saleCartControllerProvider.notifier)
                                .remove(item.product.levelGuid);
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.product.displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: remove,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  onPressed: () => update(item.quantity - 1),
                                  icon: const Icon(Icons.remove, size: 17),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    _number(item.quantity),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton.filledTonal(
                                  onPressed:
                                      purchaseMode ||
                                          item.quantity < item.product.stock
                                      ? () => update(item.quantity + 1)
                                      : null,
                                  icon: const Icon(Icons.add, size: 17),
                                ),
                                const Spacer(),
                                Text(
                                  '\$${(purchaseMode ? item.subtotal : item.total).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
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
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE7ECF5))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: items.isEmpty
                        ? null
                        : purchaseMode
                        ? () => SaleCartSheet.show(context, purchaseMode: true)
                        : () => _goToCheckout(context, ref),
                    icon: Icon(
                      purchaseMode
                          ? Icons.inventory_2_outlined
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      purchaseMode ? 'Revisar compra' : 'Continuar al checkout',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _goToCheckout(BuildContext context, WidgetRef ref) async {
    final clients = await ref.read(clientsRepositoryProvider).getAll();
    final matches = clients.where(
      (client) => client.guid == AppConstants.publicCustomerGuid,
    );
    if (!context.mounted || matches.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincroniza el catálogo Clientes primero.'),
          ),
        );
      }
      return;
    }
    ref.read(checkoutControllerProvider.notifier).selectClient(matches.first);
    context.push(AppConstants.checkoutScreenRoute);
  }
}

class _EmptyTabletCart extends StatelessWidget {
  const _EmptyTabletCart();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shopping_cart_outlined, size: 54, color: AppColors.textGrey),
        SizedBox(height: 12),
        Text(
          'Agrega artículos para comenzar',
          style: TextStyle(color: AppColors.textGrey),
        ),
      ],
    ),
  );
}

class _ProductCard extends StatelessWidget {
  final InventoryItem product;
  final bool purchaseMode;
  final VoidCallback onTap;
  const _ProductCard({
    required this.product,
    required this.purchaseMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: const BorderSide(color: Color(0xFFE7ECF5)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ProductImage(imagePath: product.imagePath, iconSize: 27),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.code}${product.barcode.isEmpty ? '' : '  •  ${product.barcode}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      product.packageLevel,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Existencia',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 10.5),
                ),
                Text(
                  _number(product.stock),
                  style: TextStyle(
                    color: product.stock > 0
                        ? AppColors.navy
                        : const Color(0xFFD92D20),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  purchaseMode ? 'Precio compra' : 'Precio',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 10.5,
                  ),
                ),
                Text(
                  '\$${(purchaseMode ? product.purchasePrice : product.salePrice).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
