import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/clients/data/repositories/clients_repository.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';

class ClientsController extends AsyncNotifier<List<Client>> {
  String? lastError;
  @override
  Future<List<Client>> build() => ref.read(clientsRepositoryProvider).getAll();

  Future<bool> create(ClientDraft draft) =>
      _mutate(() => ref.read(clientsRepositoryProvider).create(draft));

  Future<bool> updateClient(Client client, ClientDraft draft) => _mutate(
    () => ref.read(clientsRepositoryProvider).update(client.guid, draft),
  );

  Future<bool> toggle(Client client) => _mutate(
    () => ref
        .read(clientsRepositoryProvider)
        .setActive(client.guid, active: !client.isActive),
  );

  Future<bool> delete(Client client) =>
      _mutate(() => ref.read(clientsRepositoryProvider).delete(client.guid));

  Future<bool> _mutate(Future<void> Function() action) async {
    lastError = null;
    final previous = state.value ?? const <Client>[];
    state = const AsyncLoading();
    try {
      await action();
      state = AsyncData(await ref.read(clientsRepositoryProvider).getAll());
      return true;
    } catch (error, stack) {
      lastError = error.toString();
      state = AsyncError(error, stack);
      await Future<void>.delayed(Duration.zero);
      state = AsyncData(previous);
      return false;
    }
  }
}

final clientsControllerProvider =
    AsyncNotifierProvider<ClientsController, List<Client>>(
      ClientsController.new,
    );
