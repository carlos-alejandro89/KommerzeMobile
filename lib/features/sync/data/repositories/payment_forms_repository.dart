import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/payment_forms_api.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/payment_forms_local_data_source.dart';

class PaymentFormsSyncResult {
  final int records;
  final DateTime synchronizedAt;
  const PaymentFormsSyncResult({
    required this.records,
    required this.synchronizedAt,
  });
}

class PaymentFormsLocalStatus {
  final int records;
  final DateTime? synchronizedAt;
  const PaymentFormsLocalStatus({
    required this.records,
    required this.synchronizedAt,
  });
}

class PaymentFormsRepository {
  final PaymentFormsApi api;
  final PaymentFormsLocalDataSource local;
  const PaymentFormsRepository(this.api, this.local);

  Future<PaymentFormsSyncResult> synchronize() async {
    final items = await api.getAll();
    final now = DateTime.now();
    await local.replaceAll(items, now);
    return PaymentFormsSyncResult(records: items.length, synchronizedAt: now);
  }

  Future<PaymentFormsLocalStatus> localStatus() async =>
      PaymentFormsLocalStatus(
        records: await local.count(),
        synchronizedAt: await local.lastSynchronization(),
      );
}

final paymentFormsRepositoryProvider = Provider<PaymentFormsRepository>(
  (ref) => PaymentFormsRepository(
    ref.read(paymentFormsApiProvider),
    ref.read(paymentFormsLocalDataSourceProvider),
  ),
);
