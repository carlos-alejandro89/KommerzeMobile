import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sales_history/data/datasources/sales_history_local_data_source.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_history_item.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_detail.dart';
import 'package:kommerze_mobile/features/sales/data/repositories/sales_repository.dart';

class SalesHistoryRepository {
  final SalesHistoryLocalDataSource local;
  final SalesRepository sales;
  const SalesHistoryRepository(this.local, this.sales);

  Future<List<SaleHistoryItem>> getAll() => local.getAll();
  Future<List<SaleHistoryItem>> getRecent({int limit = 3}) =>
      local.getAll(limit: limit);
  Future<SaleDetail?> getDetail(String orderGuid) => local.getDetail(orderGuid);
  Future<void> cancelSale(String orderGuid) async {
    await local.cancelSale(orderGuid);
    final report = await sales.syncPending();
    final failure = report.failures[orderGuid];
    if (failure != null) {
      throw SaleCancellationSyncException(failure);
    }
    if (!report.isSynchronized(orderGuid)) {
      throw const SaleCancellationSyncException(
        'La venta se canceló localmente, pero no fue confirmada por Kommerze Cloud.',
      );
    }
  }
}

class SaleCancellationSyncException implements Exception {
  final String message;
  const SaleCancellationSyncException(this.message);

  @override
  String toString() => message;
}

final salesHistoryRepositoryProvider = Provider<SalesHistoryRepository>(
  (ref) => SalesHistoryRepository(
    ref.read(salesHistoryLocalDataSourceProvider),
    ref.read(salesRepositoryProvider),
  ),
);
