import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sales_history/data/datasources/sales_history_local_data_source.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_history_item.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_detail.dart';

class SalesHistoryRepository {
  final SalesHistoryLocalDataSource local;
  const SalesHistoryRepository(this.local);

  Future<List<SaleHistoryItem>> getAll() => local.getAll();
  Future<List<SaleHistoryItem>> getRecent({int limit = 3}) =>
      local.getAll(limit: limit);
  Future<SaleDetail?> getDetail(String orderGuid) => local.getDetail(orderGuid);
}

final salesHistoryRepositoryProvider = Provider<SalesHistoryRepository>(
  (ref) =>
      SalesHistoryRepository(ref.read(salesHistoryLocalDataSourceProvider)),
);
