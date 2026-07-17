import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/order_types_api.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/order_types_local_data_source.dart';

class OrderTypesSyncResult {
  final int records;
  final DateTime synchronizedAt;
  const OrderTypesSyncResult({
    required this.records,
    required this.synchronizedAt,
  });
}

class OrderTypesLocalStatus {
  final int records;
  final DateTime? synchronizedAt;
  const OrderTypesLocalStatus({
    required this.records,
    required this.synchronizedAt,
  });
}

class OrderTypesRepository {
  final OrderTypesApi api;
  final OrderTypesLocalDataSource local;
  const OrderTypesRepository(this.api, this.local);

  Future<OrderTypesSyncResult> synchronize() async {
    final items = await api.getAll();
    final now = DateTime.now();
    await local.replaceAll(items, now);
    return OrderTypesSyncResult(records: items.length, synchronizedAt: now);
  }

  Future<OrderTypesLocalStatus> localStatus() async => OrderTypesLocalStatus(
    records: await local.count(),
    synchronizedAt: await local.lastSynchronization(),
  );
}

final orderTypesRepositoryProvider = Provider<OrderTypesRepository>(
  (ref) => OrderTypesRepository(
    ref.read(orderTypesApiProvider),
    ref.read(orderTypesLocalDataSourceProvider),
  ),
);
