import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sales/data/datasources/sales_local_data_source.dart';
import 'package:kommerze_mobile/features/sales/data/datasources/sales_remote_data_source.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_cart_item.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_order.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_payment_draft.dart';

class SalesRepository {
  final SalesLocalDataSource local;
  final SalesRemoteDataSource remote;
  const SalesRepository(this.local, this.remote);

  Future<SaleOrder> save({
    required String clientGuid,
    required bool isCredit,
    required List<SaleCartItem> items,
    required List<SalePaymentDraft> payments,
    required String statusName,
  }) => local.create(
    clientGuid: clientGuid,
    isCredit: isCredit,
    items: items,
    payments: payments,
    statusName: statusName,
  );

  Future<List<SaleOrder>> getPending() => local.getPending();

  Future<SaleOrder> savePurchase(List<SaleCartItem> items) =>
      local.createPurchase(items);

  Future<void> sync(SaleOrder order) async {
    await remote.register(order);
    await local.markAsSent(order.orderGuid);
  }

  Future<SalesSyncReport> syncPending() async {
    final pending = await local.getPending();
    final synchronized = <String>[];
    final failures = <String, String>{};
    for (final order in pending) {
      try {
        await sync(order);
        synchronized.add(order.orderGuid);
      } catch (error) {
        failures[order.orderGuid] = error.toString();
      }
    }
    return SalesSyncReport(
      pending: pending.length,
      synchronizedOrderGuids: synchronized,
      failures: failures,
    );
  }
}

class SalesSyncReport {
  final int pending;
  final List<String> synchronizedOrderGuids;
  final Map<String, String> failures;

  const SalesSyncReport({
    required this.pending,
    required this.synchronizedOrderGuids,
    required this.failures,
  });

  int get synchronized => synchronizedOrderGuids.length;
  bool isSynchronized(String orderGuid) =>
      synchronizedOrderGuids.contains(orderGuid);
}

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepository(
    ref.read(salesLocalDataSourceProvider),
    ref.read(salesRemoteDataSourceProvider),
  ),
);
