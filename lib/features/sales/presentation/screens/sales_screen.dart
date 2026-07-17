import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:kommerze_mobile/features/purchases/presentation/controllers/purchases_controller.dart';
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
                suffixIcon: IconButton(
                  onPressed: () => _scanCamera(),
                  icon: const Icon(
                    Icons.document_scanner_outlined,
                    color: AppColors.primaryBlue,
                  ),
                ),
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
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                        itemCount:
                            state.items.length + (state.loadingMore ? 1 : 0),
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
                                onTap: () => _selectProduct(state.items[index]),
                              ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            SaleCartSheet.show(context, purchaseMode: widget.purchaseMode),
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
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primaryBlue,
                size: 27,
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
