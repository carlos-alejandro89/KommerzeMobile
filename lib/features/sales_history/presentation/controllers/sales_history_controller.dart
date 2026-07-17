import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sales_history/data/repositories/sales_history_repository.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_history_item.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_detail.dart';

final recentSalesProvider = FutureProvider<List<SaleHistoryItem>>(
  (ref) => ref.read(salesHistoryRepositoryProvider).getRecent(),
);

final salesHistoryProvider = FutureProvider<List<SaleHistoryItem>>(
  (ref) => ref.read(salesHistoryRepositoryProvider).getAll(),
);

final saleDetailProvider = FutureProvider.family<SaleDetail?, String>(
  (ref, orderGuid) =>
      ref.read(salesHistoryRepositoryProvider).getDetail(orderGuid),
);

class DailySalesAnalytics {
  final double todayTotal;
  final double yesterdayTotal;
  final List<double> hourlyTotals;

  const DailySalesAnalytics({
    required this.todayTotal,
    required this.yesterdayTotal,
    required this.hourlyTotals,
  });

  const DailySalesAnalytics.empty()
    : todayTotal = 0,
      yesterdayTotal = 0,
      hourlyTotals = const [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ];

  double get variationPercentage {
    if (yesterdayTotal == 0) return todayTotal == 0 ? 0 : 100;
    return ((todayTotal - yesterdayTotal) / yesterdayTotal) * 100;
  }

  factory DailySalesAnalytics.fromItems(
    List<SaleHistoryItem> items, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final hourly = List<double>.filled(24, 0);
    var todayTotal = 0.0;
    var yesterdayTotal = 0.0;
    for (final item in items) {
      if (item.statusName.toLowerCase() == 'cancelado') continue;
      final date = item.date.toLocal();
      final day = DateTime(date.year, date.month, date.day);
      if (day == today) {
        todayTotal += item.total;
        hourly[date.hour] += item.total;
      } else if (day == yesterday) {
        yesterdayTotal += item.total;
      }
    }
    return DailySalesAnalytics(
      todayTotal: todayTotal,
      yesterdayTotal: yesterdayTotal,
      hourlyTotals: List.unmodifiable(hourly),
    );
  }
}

final dailySalesAnalyticsProvider = FutureProvider<DailySalesAnalytics>((
  ref,
) async {
  final items = await ref.watch(salesHistoryProvider.future);
  return DailySalesAnalytics.fromItems(items);
});
