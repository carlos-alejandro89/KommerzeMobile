import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/statuses_api.dart';
import 'package:kommerze_mobile/features/sync/data/datasources/statuses_local_data_source.dart';

class StatusesSyncResult {
  final int records;
  final DateTime synchronizedAt;
  const StatusesSyncResult({
    required this.records,
    required this.synchronizedAt,
  });
}

class StatusesLocalStatus {
  final int records;
  final DateTime? synchronizedAt;
  const StatusesLocalStatus({
    required this.records,
    required this.synchronizedAt,
  });
}

class StatusesRepository {
  final StatusesApi api;
  final StatusesLocalDataSource local;
  const StatusesRepository(this.api, this.local);

  Future<StatusesSyncResult> synchronize() async {
    final items = await api.getAll();
    final now = DateTime.now();
    await local.replaceAll(items, now);
    return StatusesSyncResult(records: items.length, synchronizedAt: now);
  }

  Future<StatusesLocalStatus> localStatus() async => StatusesLocalStatus(
    records: await local.count(),
    synchronizedAt: await local.lastSynchronization(),
  );
}

final statusesRepositoryProvider = Provider<StatusesRepository>(
  (ref) => StatusesRepository(
    ref.read(statusesApiProvider),
    ref.read(statusesLocalDataSourceProvider),
  ),
);
