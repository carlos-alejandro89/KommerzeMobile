import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_cart_item.dart';

class SalesCatalogState {
  final List<InventoryItem> items;
  final String query;
  final bool loadingMore;
  final bool hasMore;

  const SalesCatalogState({
    this.items = const [],
    this.query = '',
    this.loadingMore = false,
    this.hasMore = true,
  });

  SalesCatalogState copyWith({
    List<InventoryItem>? items,
    String? query,
    bool? loadingMore,
    bool? hasMore,
  }) => SalesCatalogState(
    items: items ?? this.items,
    query: query ?? this.query,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
  );
}

class SalesCatalogController extends AsyncNotifier<SalesCatalogState> {
  static const _pageSize = 30;
  InventoryLocalDataSource get _local =>
      ref.read(inventoryLocalDataSourceProvider);

  @override
  Future<SalesCatalogState> build() async {
    final items = await _local.searchItems(limit: _pageSize);
    return SalesCatalogState(items: items, hasMore: items.length == _pageSize);
  }

  Future<void> search(String query) async {
    final normalized = query.trim();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await _local.searchItems(
        query: normalized,
        limit: _pageSize,
      );
      return SalesCatalogState(
        items: items,
        query: normalized,
        hasMore: items.length == _pageSize,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    final next = await _local.searchItems(
      query: current.query,
      limit: _pageSize,
      offset: current.items.length,
    );
    state = AsyncData(
      current.copyWith(
        items: [...current.items, ...next],
        loadingMore: false,
        hasMore: next.length == _pageSize,
      ),
    );
  }

  Future<InventoryItem?> findByBarcode(String value) =>
      _local.findByBarcode(value);
}

final salesCatalogControllerProvider =
    AsyncNotifierProvider<SalesCatalogController, SalesCatalogState>(
      SalesCatalogController.new,
    );

class SaleCartController extends Notifier<List<SaleCartItem>> {
  @override
  List<SaleCartItem> build() => const [];

  bool add(InventoryItem product, double quantity) {
    if (quantity <= 0 || quantity > product.stock) return false;
    final index = state.indexWhere(
      (item) => item.product.levelGuid == product.levelGuid,
    );
    if (index < 0) {
      state = [
        ...state,
        SaleCartItem(
          product: product,
          quantity: quantity,
          unitPrice: product.salePrice,
        ),
      ];
      return true;
    }
    final totalQuantity = state[index].quantity + quantity;
    if (totalQuantity > product.stock) return false;
    final updated = [...state];
    updated[index] = updated[index].copyWith(quantity: totalQuantity);
    state = updated;
    return true;
  }

  void updateQuantity(String levelGuid, double quantity) {
    if (quantity <= 0) return remove(levelGuid);
    state = [
      for (final item in state)
        if (item.product.levelGuid == levelGuid &&
            quantity <= item.product.stock)
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

final saleCartControllerProvider =
    NotifierProvider<SaleCartController, List<SaleCartItem>>(
      SaleCartController.new,
    );
final saleCartTotalProvider = Provider<double>(
  (ref) => ref
      .watch(saleCartControllerProvider)
      .fold(0, (total, item) => total + item.total),
);
