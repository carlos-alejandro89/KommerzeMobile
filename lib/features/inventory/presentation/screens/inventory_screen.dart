import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/core/widgets/product_image.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:kommerze_mobile/features/inventory/presentation/controllers/inventory_controller.dart';

enum _StockFilter { all, low, empty }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  static const _pageSize = 30;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  _StockFilter _filter = _StockFilter.all;
  int _visibleLimit = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadNextPage);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_loadNextPage)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryControllerProvider);
    final items = inventory.value ?? const <InventoryItem>[];
    final filteredItems = _filterItems(items);
    final visibleItems = filteredItems.take(_visibleLimit).toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Inventario',
            height: 256 + MediaQuery.paddingOf(context).top,
            showBackButton: true,
            onBack: context.pop,
            actions: [
              PopupMenuButton<_InventoryAction>(
                tooltip: 'Opciones de inventario',
                color: Colors.white,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: _runAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _InventoryAction.syncPrices,
                    child: _ActionLabel(
                      icon: Icons.sync_rounded,
                      text: 'Sincronizar precios',
                    ),
                  ),
                  PopupMenuItem(
                    value: _InventoryAction.recoverInventory,
                    child: _ActionLabel(
                      icon: Icons.inventory_2_outlined,
                      text: 'Recuperar inventario',
                    ),
                  ),
                ],
              ),
            ],
            content: _headerContent(items),
          ),
          Expanded(
            child: inventory.when(
              skipLoadingOnRefresh: true,
              data: (_) => _content(filteredItems, visibleItems),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(inventoryControllerProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerContent(List<InventoryItem> items) {
    final inventoryValue = items.fold<double>(
      0,
      (total, item) => total + (item.stock * item.purchasePrice),
    );
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _resetPagination(),
            style: const TextStyle(color: AppColors.navy, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar código, nombre, línea o marca...',
              hintStyle: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 21),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _resetPagination();
                      },
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.inventory_2_outlined,
                label: 'Artículos',
                value: '${items.length}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                icon: Icons.layers_outlined,
                label: 'Valor inventario',
                value: _money(inventoryValue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _FilterChip(
              text: 'Todos',
              selected: _filter == _StockFilter.all,
              onTap: () => _changeFilter(_StockFilter.all),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              text: 'Bajo stock',
              selected: _filter == _StockFilter.low,
              onTap: () => _changeFilter(_StockFilter.low),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              text: 'Sin existencia',
              selected: _filter == _StockFilter.empty,
              onTap: () => _changeFilter(_StockFilter.empty),
            ),
          ],
        ),
      ],
    );
  }

  Widget _content(
    List<InventoryItem> filteredItems,
    List<InventoryItem> visibleItems,
  ) {
    final hasMore = visibleItems.length < filteredItems.length;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(inventoryControllerProvider),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (visibleItems.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              sliver: SliverList.separated(
                itemCount: visibleItems.length + (hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  if (index == visibleItems.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return _InventoryCard(item: visibleItems[index]);
                },
              ),
            ),
        ],
      ),
    );
  }

  void _changeFilter(_StockFilter filter) {
    setState(() {
      _filter = filter;
      _visibleLimit = _pageSize;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _resetPagination() {
    setState(() => _visibleLimit = _pageSize);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _loadNextPage() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 280) {
      return;
    }
    final total = _filterItems(
      ref.read(inventoryControllerProvider).value ?? const [],
    ).length;
    if (_visibleLimit >= total) return;
    setState(() {
      final nextLimit = _visibleLimit + _pageSize;
      _visibleLimit = nextLimit > total ? total : nextLimit;
    });
  }

  List<InventoryItem> _filterItems(List<InventoryItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    return items
        .where((item) {
          final matchesSearch =
              query.isEmpty ||
              item.code.toLowerCase().contains(query) ||
              item.displayName.toLowerCase().contains(query) ||
              item.barcode.toLowerCase().contains(query) ||
              item.lineName.toLowerCase().contains(query) ||
              item.brandName.toLowerCase().contains(query);
          final matchesStock = switch (_filter) {
            _StockFilter.all => true,
            _StockFilter.low => item.stock > 0 && item.stock <= 10,
            _StockFilter.empty => item.stock <= 0,
          };
          return matchesSearch && matchesStock;
        })
        .toList(growable: false);
  }

  Future<void> _runAction(_InventoryAction action) async {
    final controller = ref.read(inventoryControllerProvider.notifier);
    final success = action == _InventoryAction.syncPrices
        ? await controller.syncPrices()
        : await controller.recoverInventory();
    if (!mounted) return;
    final state = ref.read(inventoryControllerProvider);
    _showMessage(
      success
          ? action == _InventoryAction.syncPrices
                ? 'Precios sincronizados correctamente.'
                : 'Inventario recuperado correctamente.'
          : state.error.toString(),
      success: success,
    );
  }

  void _showMessage(String message, {required bool success}) {
    final color = success ? AppColors.success : AppColors.error;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: success
              ? AppColors.successSoft
              : AppColors.errorSoft,
          elevation: 1,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withValues(alpha: .2)),
          ),
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.navy, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

enum _InventoryAction { syncPrices, recoverInventory }

class _ActionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ActionLabel({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.primaryBlue, size: 20),
      const SizedBox(width: 10),
      Text(text),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.borderGrey,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.primaryBlue : AppColors.textGrey,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  const _InventoryCard({required this.item});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 126,
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: AppColors.primaryLight.withValues(alpha: .9),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ProductImage(imagePath: item.imagePath, iconSize: 34),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    item.code,
                    item.brandName,
                  ].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Flexible(
                      child: _InventoryBadge(
                        label: 'Nivel: ${item.packageLevel}',
                        background: AppColors.primaryLight,
                        foreground: AppColors.navySoft,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _InventoryBadge(
                      label:
                          'Desc. ${item.discountPercentage.toStringAsFixed(0)}%',
                      background: AppColors.estatusPendienteFondo,
                      foreground: AppColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Existencia',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 9.5),
                ),
                Text(
                  _quantity(item.stock),
                  style: TextStyle(
                    color: item.stock <= 0 ? AppColors.error : AppColors.navy,
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Precio venta',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 9.5),
                ),
                Text(
                  '\$${item.salePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.primaryBlue,
            size: 21,
          ),
        ],
      ),
    ),
  );

  static String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

class _InventoryBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _InventoryBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: foreground,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, color: AppColors.textGrey, size: 42),
          SizedBox(height: 10),
          Text(
            'No se encontraron artículos.',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}
