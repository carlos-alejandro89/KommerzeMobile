import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/clients/data/datasources/clients_api.dart';
import 'package:kommerze_mobile/features/clients/data/datasources/clients_local_data_source.dart';

class ClientsSyncResult {
  final int records;
  final DateTime synchronizedAt;
  const ClientsSyncResult({
    required this.records,
    required this.synchronizedAt,
  });
}

class ClientsLocalStatus {
  final int records;
  final DateTime? synchronizedAt;
  const ClientsLocalStatus({
    required this.records,
    required this.synchronizedAt,
  });
}

class ClientsSyncRepository {
  final ClientsApi api;
  final ClientsLocalDataSource local;
  const ClientsSyncRepository(this.api, this.local);

  Future<ClientsSyncResult> synchronize() async {
    final clients = await api.listAll();
    final now = DateTime.now();
    await local.upsertRemote(clients, syncedAt: now);
    return ClientsSyncResult(records: clients.length, synchronizedAt: now);
  }

  Future<ClientsLocalStatus> localStatus() async => ClientsLocalStatus(
    records: await local.synchronizedCount(),
    synchronizedAt: await local.lastSynchronization(),
  );
}

final clientsSyncRepositoryProvider = Provider<ClientsSyncRepository>(
  (ref) => ClientsSyncRepository(
    ref.read(clientsApiProvider),
    ref.read(clientsLocalDataSourceProvider),
  ),
);
