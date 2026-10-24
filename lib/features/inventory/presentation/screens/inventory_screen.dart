import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/core/widgets/product_image.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:kommerze_mobile/features/inventory/data/services/inventory_thermal_printer_service.dart';
import 'package:kommerze_mobile/features/inventory/presentation/controllers/inventory_controller.dart';
import 'package:kommerze_mobile/features/inventory/presentation/widgets/inventory_confirmation_sheet.dart';
import 'package:kommerze_mobile/features/license/presentation/controllers/license_activation_controller.dart';
import 'package:kommerze_mobile/features/printer/presentation/controllers/printer_settings_controller.dart';
import 'package:kommerze_mobile/core/inventory/inventory_source_controller.dart';

enum _StockFilter { inStock, low, empty }

const _summaryTitleStyle = TextStyle(
  color: AppColors.navy,
  fontSize: 12,
  fontWeight: FontWeight.w700,
);

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  static const _pageSize = 30;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<_StockFilter> _stockFilters = {};
  Set<String> _selectedLines = {};
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
    final cloudInventory =
        ref.watch(inventorySourceControllerProvider) == InventorySource.cloud;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Inventario',
            height: 232 + MediaQuery.paddingOf(context).top,
            showBackButton: true,
            onBack: context.pop,
            actions: [
              PopupMenuButton<_InventoryAction>(
                tooltip: 'Opciones de inventario',
                color: Colors.white,
                enabled: !inventory.isLoading,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: _runAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _InventoryAction.syncPrices,
                    child: _ActionLabel(
                      icon: Icons.sync_rounded,
                      text: 'Sincronizar precios',
                    ),
                  ),
                  if (!cloudInventory) ...const [
                    PopupMenuItem(
                      value: _InventoryAction.recoverInventory,
                      child: _ActionLabel(
                        icon: Icons.cloud_download_outlined,
                        text: 'Recuperar inventario',
                      ),
                    ),
                    PopupMenuItem(
                      value: _InventoryAction.backupInventory,
                      child: _ActionLabel(
                        icon: Icons.cloud_upload_outlined,
                        text: 'Respaldar inventario',
                      ),
                    ),
                  ],
                ],
              ),
            ],
            content: _headerContent(items, filteredItems),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: inventory.isLoading ? null : _showPrintSummary,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.print_outlined),
        label: const Text('Imprimir'),
      ),
    );
  }

  Widget _headerContent(
    List<InventoryItem> items,
    List<InventoryItem> filteredItems,
  ) {
    final inventoryValue = filteredItems.fold<double>(
      0,
      (total, item) => total + (item.stock * item.salePrice),
    );
    return Column(
      children: [
        SizedBox(
          height: 42,
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.inventory_2_outlined,
                label: 'Artículos',
                value: '${filteredItems.length}',
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
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _FilterChip(
                text: _selectedLines.isEmpty
                    ? 'Líneas'
                    : 'Líneas · ${_selectedLines.length}',
                selected: _selectedLines.isNotEmpty,
                icon: Icons.tune_rounded,
                onTap: () => _selectLines(items),
              ),
              const SizedBox(width: 7),
              _FilterChip(
                text: 'Todos',
                selected: _stockFilters.isEmpty,
                onTap: _clearStockFilters,
              ),
              const SizedBox(width: 7),
              _FilterChip(
                text: 'Con Existencia',
                selected: _stockFilters.contains(_StockFilter.inStock),
                onTap: () => _toggleStockFilter(_StockFilter.inStock),
              ),
              const SizedBox(width: 7),
              _FilterChip(
                text: 'Bajo stock',
                selected: _stockFilters.contains(_StockFilter.low),
                onTap: () => _toggleStockFilter(_StockFilter.low),
              ),
              const SizedBox(width: 7),
              _FilterChip(
                text: 'Sin existencia',
                selected: _stockFilters.contains(_StockFilter.empty),
                onTap: () => _toggleStockFilter(_StockFilter.empty),
              ),
            ],
          ),
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

  void _toggleStockFilter(_StockFilter filter) {
    setState(() {
      if (!_stockFilters.add(filter)) _stockFilters.remove(filter);
      _visibleLimit = _pageSize;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _clearStockFilters() {
    setState(() {
      _stockFilters.clear();
      _visibleLimit = _pageSize;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _selectLines(List<InventoryItem> items) async {
    final available = items.map(_normalizedLine).toSet().toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _LineFilterSheet(lines: available, selectedLines: _selectedLines),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedLines = selected;
      _visibleLimit = _pageSize;
    });
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
          final matchesStock =
              _stockFilters.isEmpty ||
              (_stockFilters.contains(_StockFilter.inStock) &&
                  item.stock > 10) ||
              (_stockFilters.contains(_StockFilter.low) &&
                  item.stock > 0 &&
                  item.stock <= 10) ||
              (_stockFilters.contains(_StockFilter.empty) && item.stock <= 0);
          final matchesLine =
              _selectedLines.isEmpty ||
              _selectedLines.contains(_normalizedLine(item));
          return matchesSearch && matchesStock && matchesLine;
        })
        .toList(growable: false);
  }

  Future<void> _runAction(_InventoryAction action) async {
    if (action != _InventoryAction.syncPrices) {
      await _confirmCriticalAction(action);
      return;
    }
    final controller = ref.read(inventoryControllerProvider.notifier);
    final success = await controller.syncPrices();
    if (!mounted) return;
    final state = ref.read(inventoryControllerProvider);
    _showMessage(
      success ? _successMessage(action) : state.error.toString(),
      success: success,
    );
  }

  Future<void> _showPrintSummary() async {
    final inventory = ref.read(inventoryControllerProvider).value ?? const [];
    final items = _filterItems(inventory);
    if (items.isEmpty) {
      _showMessage(
        'No hay artículos con los filtros aplicados.',
        success: false,
      );
      return;
    }
    final stockLabels = _stockFilterLabels();
    final filteredValue = items.fold<double>(
      0,
      (total, item) => total + item.stock * item.salePrice,
    );
    final lineLabels = _selectedLines.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderGrey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Resumen de impresión',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${items.length} artículos coinciden con los filtros aplicados.',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Valor del inventario filtrado',
                        style: TextStyle(
                          color: AppColors.navySoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _money(filteredValue),
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Existencia', style: _summaryTitleStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: stockLabels
                    .map((label) => _FilterSummaryChip(label: label))
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              const Text('Líneas', style: _summaryTitleStyle),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children:
                        (lineLabels.isEmpty ? const ['Todas'] : lineLabels)
                            .map((label) => _FilterSummaryChip(label: label))
                            .toList(growable: false),
                  ),
                ),
              ),
              if (_searchController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Búsqueda', style: _summaryTitleStyle),
                const SizedBox(height: 8),
                _FilterSummaryChip(label: _searchController.text.trim()),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Confirmar impresión'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _printInventory(items);
  }

  Future<void> _printInventory(List<InventoryItem> items) async {
    try {
      _showMessage('Enviando inventario a la miniprinter...', success: true);
      final branch = (await ref.read(licenseDetailsProvider.future))?.branch;
      await const InventoryThermalPrinterService().printInventory(
        items,
        ref.read(printerSettingsControllerProvider),
        scopeLabel: _stockFilterLabels().join(', '),
        branchName: branch?.name ?? '',
        branchAddress: branch?.address ?? '',
        branchPhone: branch?.phone ?? '',
        branchEmail: branch?.email ?? '',
      );
      if (!mounted) return;
      _showMessage('Inventario enviado a la miniprinter.', success: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString(), success: false);
    }
  }

  List<String> _stockFilterLabels() {
    if (_stockFilters.isEmpty) return const ['Todos'];
    return [
      if (_stockFilters.contains(_StockFilter.inStock)) 'Con Existencia',
      if (_stockFilters.contains(_StockFilter.low)) 'Bajo stock',
      if (_stockFilters.contains(_StockFilter.empty)) 'Sin existencia',
    ];
  }

  String _normalizedLine(InventoryItem item) {
    final value = item.lineName.trim();
    return value.isEmpty ? 'SIN LÍNEA' : value;
  }

  Future<void> _confirmCriticalAction(_InventoryAction action) async {
    final kind = action == _InventoryAction.backupInventory
        ? InventoryConfirmationKind.backup
        : InventoryConfirmationKind.recover;
    await showInventoryConfirmationSheet(
      context: context,
      kind: kind,
      onConfirm: () async {
        final controller = ref.read(inventoryControllerProvider.notifier);
        final success = action == _InventoryAction.backupInventory
            ? await controller.backupInventory()
            : await controller.recoverInventory();
        if (success) return;
        final error = ref.read(inventoryControllerProvider).error;
        throw Exception(
          error?.toString() ?? 'No fue posible completar la acción.',
        );
      },
    );
  }

  String _successMessage(_InventoryAction action) => switch (action) {
    _InventoryAction.syncPrices => 'Precios sincronizados correctamente.',
    _InventoryAction.recoverInventory => 'Inventario recuperado correctamente.',
    _InventoryAction.backupInventory => 'Inventario respaldado correctamente.',
  };

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

class _LineFilterSheet extends StatefulWidget {
  final List<String> lines;
  final Set<String> selectedLines;

  const _LineFilterSheet({required this.lines, required this.selectedLines});

  @override
  State<_LineFilterSheet> createState() => _LineFilterSheetState();
}

class _LineFilterSheetState extends State<_LineFilterSheet> {
  final _searchController = TextEditingController();
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedLines};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = widget.lines
        .where((line) => query.isEmpty || line.toLowerCase().contains(query))
        .toList(growable: false);
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * .72,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderGrey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtrar por líneas',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: const Text('Ver todas'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar línea...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.lightBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _selected.isEmpty
                  ? 'Todas las líneas'
                  : '${_selected.length} seleccionada${_selected.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final line in visible)
                      FilterChip(
                        label: Text(line),
                        selected: _selected.contains(line),
                        showCheckmark: true,
                        selectedColor: AppColors.primaryLight,
                        checkmarkColor: AppColors.primaryBlue,
                        side: BorderSide(
                          color: _selected.contains(line)
                              ? AppColors.primaryBlue
                              : AppColors.borderGrey,
                        ),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _selected.add(line);
                          } else {
                            _selected.remove(line);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, Set.of(_selected)),
              child: const Text('Aplicar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSummaryChip extends StatelessWidget {
  final String label;

  const _FilterSummaryChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.primaryLight),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.primaryBlue,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

enum _InventoryAction { syncPrices, recoverInventory, backupInventory }

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
    height: 46,
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
  final IconData? icon;
  final VoidCallback onTap;
  const _FilterChip({
    required this.text,
    required this.selected,
    this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.primaryBlue : AppColors.borderGrey,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.primaryBlue : AppColors.textGrey,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            maxLines: 1,
            style: TextStyle(
              color: selected ? AppColors.primaryBlue : AppColors.textGrey,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
