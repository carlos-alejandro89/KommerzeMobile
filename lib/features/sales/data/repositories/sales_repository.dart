import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/inventory/inventory_source_controller.dart';
import 'package:kommerze_mobile/features/inventory/data/repositories/inventory_repository.dart';
import 'package:kommerze_mobile/features/sales/data/datasources/sales_local_data_source.dart';
import 'package:kommerze_mobile/features/sales/data/datasources/sales_remote_data_source.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_cart_item.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_order.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_payment_draft.dart';

class SalesRepository {
  final SalesLocalDataSource local;
  final SalesRemoteDataSource remote;
  final InventoryRepository inventory;
  final InventorySource inventorySource;
  const SalesRepository(
    this.local,
    this.remote,
    this.inventory,
    this.inventorySource,
  );

  Future<SaleOrder> save({
    required String clientGuid,
    required bool isCredit,
    required List<SaleCartItem> items,
    required List<SalePaymentDraft> payments,
    required String statusName,
  }) async {
    if (inventorySource == InventorySource.cloud) {
      final requested = <String, double>{};
      for (final item in items) {
        requested.update(
          item.product.levelGuid,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
      final available = await inventory.validateCloudAvailability(requested);
      for (final item in items) {
        final stock = available[item.product.levelGuid] ?? 0;
        final quantity = requested[item.product.levelGuid] ?? 0;
        if (stock < quantity) {
          throw SalesInventoryException(
            'No hay existencia suficiente de ${item.product.displayName}. '
            'Disponible: ${_number(stock)}.',
          );
        }
      }
    }
    return local.create(
      clientGuid: clientGuid,
      isCredit: isCredit,
      items: items,
      payments: payments,
      statusName: statusName,
      enforceLocalStock: inventorySource == InventorySource.local,
    );
  }

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
    ref.watch(salesRemoteDataSourceProvider),
    ref.watch(inventoryRepositoryProvider),
    ref.watch(inventorySourceControllerProvider),
  ),
);

String _number(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

class SalesInventoryException implements Exception {
  final String message;
  const SalesInventoryException(this.message);

  @override
  String toString() => message;
}
