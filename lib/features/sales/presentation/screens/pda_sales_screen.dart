import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/inventory/inventory_source_controller.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/core/widgets/product_image.dart';
import 'package:kommerze_mobile/features/checkout/presentation/controllers/checkout_controller.dart';
import 'package:kommerze_mobile/features/clients/data/repositories/clients_repository.dart';
import 'package:kommerze_mobile/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:kommerze_mobile/features/inventory/data/repositories/inventory_repository.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_cart_item.dart';
import 'package:kommerze_mobile/features/sales/presentation/controllers/sales_controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PdaSalesScreen extends ConsumerStatefulWidget {
  const PdaSalesScreen({super.key});

  @override
  ConsumerState<PdaSalesScreen> createState() => _PdaSalesScreenState();
}

class _PdaSalesScreenState extends ConsumerState<PdaSalesScreen> {
  final _search = TextEditingController();
  final _focusNode = FocusNode();
  final _cartScrollController = ScrollController();
  Future<void> _scanQueue = Future.value();
  String? _lastScannedLevelGuid;

  @override
  void dispose() {
    _search.dispose();
    _focusNode.dispose();
    _cartScrollController.dispose();
    super.dispose();
  }

  void _submitBarcode(String value) {
    final code = value.trim();
    if (code.isEmpty) return;
    _search.clear();
    _focusNode.requestFocus();
    _scanQueue = _scanQueue.then((_) => _addBarcode(code));
  }

  Future<void> _addBarcode(String code) async {
    final product = await ref
        .read(salesCatalogControllerProvider.notifier)
        .findByBarcode(code);
    if (!mounted) return;
    if (product == null) {
      _message('No encontramos un artículo con el código $code.', error: true);
      return;
    }

    final added = await _addProduct(product);
    if (!added || !mounted) return;

    setState(() => _lastScannedLevelGuid = product.levelGuid);
    _scrollToProduct(product.levelGuid);
  }

  Future<bool> _addProduct(InventoryItem product) async {
    var currentProduct = product;
    if (ref.read(inventorySourceControllerProvider) == InventorySource.cloud) {
      try {
        final stock = await ref
            .read(inventoryRepositoryProvider)
            .getCloudStock(product.levelGuid);
        currentProduct = product.copyWith(stock: stock);
      } catch (error) {
        if (mounted) _message(error.toString(), error: true);
        return false;
      }
    }
    final added = ref
        .read(saleCartControllerProvider.notifier)
        .add(currentProduct, 1);
    if (!added && mounted) {
      _message(
        'No hay existencia suficiente de ${product.displayName}.',
        error: true,
      );
    }
    return added;
  }

  void _scrollToProduct(String levelGuid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_cartScrollController.hasClients) return;
      final cart = ref.read(saleCartControllerProvider);
      final index = cart.indexWhere(
        (item) => item.product.levelGuid == levelGuid,
      );
      if (index < 0) return;

      const itemExtent = 169.0;
      final position = _cartScrollController.position;
      final target = (index * itemExtent).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _cartScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(value),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? AppColors.error : AppColors.primaryBlue,
        ),
      );
  }

  Future<void> _goToCheckout() async {
    final clients = await ref.read(clientsRepositoryProvider).getAll();
    final matches = clients.where(
      (client) => client.guid == AppConstants.publicCustomerGuid,
    );
    final publicCustomer = matches.isEmpty ? null : matches.first;
    if (!mounted) return;
    if (publicCustomer == null) {
      _message(
        'Sincroniza el catálogo Clientes para usar Público General.',
        error: true,
      );
      return;
    }
    ref.read(checkoutControllerProvider.notifier).selectClient(publicCustomer);
    context.push(AppConstants.checkoutScreenRoute);
  }

  Future<void> _confirmClearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vaciar venta'),
        content: const Text('Se eliminarán todos los artículos capturados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Vaciar carrito'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(saleCartControllerProvider.notifier).clear();
      if (mounted) setState(() => _lastScannedLevelGuid = null);
    }
    _focusNode.requestFocus();
  }

  Future<void> _manualSearch() async {
    final product = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _ManualProductSearchSheet(),
    );
    if (product != null && mounted) {
      final added = await _addProduct(product);
      if (added && mounted) {
        setState(() => _lastScannedLevelGuid = product.levelGuid);
        _scrollToProduct(product.levelGuid);
      }
    }
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(saleCartControllerProvider);
    final total = ref.watch(saleCartTotalProvider);
    final units = cart.fold<double>(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Ventas',
            subtitle: 'Escanea artículos para agregarlos',
            showBackButton: true,
            onBack: () => context.go(AppConstants.welcomeScreenRoute),
            actions: [
              IconButton(
                tooltip: 'Vaciar carrito',
                onPressed: cart.isEmpty ? null : _confirmClearCart,
                icon: const Icon(
                  Icons.remove_shopping_cart_outlined,
                  color: Colors.white,
                ),
              ),
              IconButton(
                tooltip: 'Búsqueda manual',
                onPressed: _manualSearch,
                icon: const Icon(Icons.search_rounded, color: Colors.white),
              ),
            ],
          ),
          Offstage(
            offstage: true,
            child: TextField(
              controller: _search,
              focusNode: _focusNode,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.none,
              showCursor: false,
              textInputAction: TextInputAction.search,
              onSubmitted: _submitBarcode,
              decoration: const InputDecoration.collapsed(hintText: ''),
            ),
          ),
          Expanded(
            child: cart.isEmpty
                ? const _EmptyPdaSale()
                : ListView.separated(
                    controller: _cartScrollController,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
                    itemCount: cart.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = cart[index];
                      return _PdaCartItem(
                        item: item,
                        highlighted:
                            item.product.levelGuid == _lastScannedLevelGuid,
                        onDecrease: () => ref
                            .read(saleCartControllerProvider.notifier)
                            .updateQuantity(
                              item.product.levelGuid,
                              item.quantity - 1,
                            ),
                        onIncrease: () => _addProduct(item.product),
                        onRemove: () => ref
                            .read(saleCartControllerProvider.notifier)
                            .remove(item.product.levelGuid),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: FilledButton(
          onPressed: cart.isEmpty ? null : _goToCheckout,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: Text(
            'Ir a pagar  ·  ${units.toStringAsFixed(0)} artículos  ·  \$${total.toStringAsFixed(2)}',
          ),
        ),
      ),
    );
  }
}

class _ManualProductSearchSheet extends ConsumerStatefulWidget {
  const _ManualProductSearchSheet();

  @override
  ConsumerState<_ManualProductSearchSheet> createState() =>
      _ManualProductSearchSheetState();
}

class _ManualProductSearchSheetState
    extends ConsumerState<_ManualProductSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<InventoryItem> _items = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _loading = false;
        _items = const [];
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 260), () async {
      final items = await ref
          .read(inventoryLocalDataSourceProvider)
          .searchItems(query: query, limit: 30);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Buscar artículo',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Código, descripción o código de barras',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Text(
                      _controller.text.trim().isEmpty
                          ? 'Escribe para buscar en el inventario.'
                          : 'No se encontraron artículos.',
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final product = _items[index];
                      final cloudInventory =
                          ref.watch(inventorySourceControllerProvider) ==
                          InventorySource.cloud;
                      final available = cloudInventory || product.stock > 0;
                      return ListTile(
                        onTap: available
                            ? () => Navigator.pop(context, product)
                            : null,
                        tileColor: available
                            ? Colors.white
                            : AppColors.lightBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.borderGrey),
                        ),
                        leading: SizedBox.square(
                          dimension: 48,
                          child: Opacity(
                            opacity: available ? 1 : .45,
                            child: ColorFiltered(
                              colorFilter: available
                                  ? const ColorFilter.mode(
                                      Colors.transparent,
                                      BlendMode.dst,
                                    )
                                  : const ColorFilter.mode(
                                      Colors.grey,
                                      BlendMode.saturation,
                                    ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: ProductImage(
                                  imagePath: product.imagePath,
                                  iconSize: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          product.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: available
                                ? AppColors.navy
                                : AppColors.textGrey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          cloudInventory
                              ? '${product.code}  ·  Existencia en Cloud'
                              : '${product.code}  ·  Existencia ${product.stock.toStringAsFixed(0)}',
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${product.salePrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: available
                                    ? AppColors.primaryBlue
                                    : AppColors.textGrey,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (!available) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF98A3B3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Agotado',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyPdaSale extends StatelessWidget {
  const _EmptyPdaSale();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.scanBarcode, size: 62, color: AppColors.textGrey),
          SizedBox(height: 14),
          Text(
            'Escanea el primer artículo',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Cada lectura agregará una unidad y aparecerá inmediatamente aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey),
          ),
        ],
      ),
    ),
  );
}

class _PdaCartItem extends StatelessWidget {
  final SaleCartItem item;
  final bool highlighted;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  const _PdaCartItem({
    required this.item,
    required this.highlighted,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: highlighted ? AppColors.primarySurface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: highlighted ? AppColors.primaryBlue : AppColors.borderGrey,
      ),
    ),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: .9),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ProductImage(
                  imagePath: item.product.imagePath,
                  iconSize: 27,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    [
                      item.product.code,
                      item.product.brandName,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 4),
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
              onPressed: onRemove,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(backgroundColor: AppColors.errorSoft),
              color: AppColors.error,
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
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
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Disminuir cantidad',
                    onPressed: onDecrease,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                  ),
                  SizedBox(
                    width: 38,
                    child: Text(
                      item.quantity.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aumentar cantidad',
                    onPressed: onIncrease,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.add_rounded, size: 18),
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
                  style: TextStyle(color: AppColors.textGrey, fontSize: 10),
                ),
                Text(
                  '\$${item.total.toStringAsFixed(2)}',
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
}
