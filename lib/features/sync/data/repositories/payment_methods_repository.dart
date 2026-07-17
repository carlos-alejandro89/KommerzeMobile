import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/payment_methods_api.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/payment_methods_local_data_source.dart';

class PaymentMethodsSyncResult {
  final int records;
  final DateTime synchronizedAt;
  const PaymentMethodsSyncResult({
    required this.records,
    required this.synchronizedAt,
  });
}

class PaymentMethodsLocalStatus {
  final int records;
  final DateTime? synchronizedAt;
  const PaymentMethodsLocalStatus({
    required this.records,
    required this.synchronizedAt,
  });
}

class PaymentMethodsRepository {
  final PaymentMethodsApi api;
  final PaymentMethodsLocalDataSource local;
  const PaymentMethodsRepository(this.api, this.local);

  Future<PaymentMethodsSyncResult> synchronize() async {
    final items = await api.getAll();
    final now = DateTime.now();
    await local.replaceAll(items, now);
    return PaymentMethodsSyncResult(records: items.length, synchronizedAt: now);
  }

  Future<PaymentMethodsLocalStatus> localStatus() async =>
      PaymentMethodsLocalStatus(
        records: await local.count(),
        synchronizedAt: await local.lastSynchronization(),
      );
}

final paymentMethodsRepositoryProvider = Provider<PaymentMethodsRepository>(
  (ref) => PaymentMethodsRepository(
    ref.read(paymentMethodsApiProvider),
    ref.read(paymentMethodsLocalDataSourceProvider),
  ),
);
