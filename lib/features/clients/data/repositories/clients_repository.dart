import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/clients/data/datasources/clients_local_data_source.dart';
import 'package:kommerze_mobile/features/clients/data/datasources/clients_api.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';

class ClientsRepository {
  final ClientsApi api;
  final ClientsLocalDataSource local;
  const ClientsRepository(this.api, this.local);

  Future<List<Client>> getAll() => local.getAll();
  Future<void> create(ClientDraft draft) async {
    final guid = await api.create(draft);
    await local.create(draft, guid: guid);
  }

  Future<void> update(String guid, ClientDraft draft) async {
    await api.update(guid, draft);
    await local.update(guid, draft);
  }

  Future<void> setActive(String guid, {required bool active}) =>
      local.setActive(guid, active: active);
  Future<void> delete(String guid) async {
    await api.delete(guid);
    await local.delete(guid);
  }
}

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository(
    ref.read(clientsApiProvider),
    ref.read(clientsLocalDataSourceProvider),
  );
});
