import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/sync/data/repositories/order_types_repository.dart';
import 'package:kommerze_mobile/features/sync/data/repositories/payment_forms_repository.dart';
import 'package:kommerze_mobile/features/sync/data/repositories/payment_methods_repository.dart';
import 'package:kommerze_mobile/features/sync/data/repositories/profiles_repository.dart';
import 'package:kommerze_mobile/features/sync/data/repositories/statuses_repository.dart';
import 'package:kommerze_mobile/features/sync/data/repositories/clients_sync_repository.dart';
import 'package:kommerze_mobile/features/sync/data/repositories/users_repository.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/catalog_sync_item.dart';

class CatalogSyncState {
  final List<CatalogSyncItem> catalogs;
  final DateTime? lastSynchronization;
  final bool synchronizingAll;

  const CatalogSyncState({
    required this.catalogs,
    this.lastSynchronization,
    this.synchronizingAll = false,
  });

  int get totalRecords => catalogs.fold(0, (sum, item) => sum + item.records);
  int get synchronizedRecords => catalogs
      .where((item) => item.status == CatalogSyncStatus.synchronized)
      .fold(0, (sum, item) => sum + item.records);
  int get pendingCatalogs =>
      catalogs.where((item) => item.status == CatalogSyncStatus.pending).length;
  int get errors =>
      catalogs.where((item) => item.status == CatalogSyncStatus.error).length;

  CatalogSyncState copyWith({
    List<CatalogSyncItem>? catalogs,
    DateTime? lastSynchronization,
    bool? synchronizingAll,
  }) => CatalogSyncState(
    catalogs: catalogs ?? this.catalogs,
    lastSynchronization: lastSynchronization ?? this.lastSynchronization,
    synchronizingAll: synchronizingAll ?? this.synchronizingAll,
  );
}

class CatalogSyncController extends Notifier<CatalogSyncState> {
  String? lastError;

  @override
  CatalogSyncState build() {
    return const CatalogSyncState(
      catalogs: [
        CatalogSyncItem(
          type: CatalogType.paymentForms,
          title: 'Formas de pago',
          description: 'Formas de pago disponibles en el sistema',
          endpoint: '/catalogos/sat/formas-pago/get',
        ),
        CatalogSyncItem(
          type: CatalogType.paymentMethods,
          title: 'Métodos de pago',
          description: 'Métodos utilizados para registrar pagos',
          endpoint: '/catalogos/sat/metodos-pago/get',
        ),
        CatalogSyncItem(
          type: CatalogType.profiles,
          title: 'Perfiles',
          description: 'Perfiles y permisos de usuario',
          endpoint: '/catalogos/perfiles/get',
        ),
        CatalogSyncItem(
          type: CatalogType.users,
          title: 'Usuarios',
          description: 'Usuarios disponibles en el sistema',
          endpoint: '/catalogos/usuarios/get',
        ),
        CatalogSyncItem(
          type: CatalogType.clients,
          title: 'Clientes',
          description: 'Clientes disponibles para ventas y crédito',
          endpoint: '/clientes/listar',
        ),
        CatalogSyncItem(
          type: CatalogType.orderTypes,
          title: 'Tipo de pedido',
          description: 'Tipos de pedidos disponibles',
          endpoint: '/catalogos/tipos-pedido/get',
        ),
        CatalogSyncItem(
          type: CatalogType.statuses,
          title: 'Estatus',
          description: 'Estatus para pedidos y operaciones',
          endpoint: '/catalogos/estatus/get',
        ),
      ],
    );
  }

  bool canSynchronize(CatalogType type) =>
      state.catalogs.firstWhere((item) => item.type == type).endpoint != null;

  Future<bool> synchronize(CatalogType type) async {
    lastError = null;
    if (!canSynchronize(type)) {
      lastError = 'El endpoint aún no está configurado.';
      return false;
    }
    _update(type, status: CatalogSyncStatus.syncing);
    try {
      switch (type) {
        case CatalogType.paymentForms:
          final result = await ref
              .read(paymentFormsRepositoryProvider)
              .synchronize();
          _update(
            type,
            status: CatalogSyncStatus.synchronized,
            records: result.records,
            synchronizedAt: result.synchronizedAt,
          );
          state = state.copyWith(lastSynchronization: result.synchronizedAt);
          break;
        case CatalogType.paymentMethods:
          final result = await ref
              .read(paymentMethodsRepositoryProvider)
              .synchronize();
          _update(
            type,
            status: CatalogSyncStatus.synchronized,
            records: result.records,
            synchronizedAt: result.synchronizedAt,
          );
          state = state.copyWith(lastSynchronization: result.synchronizedAt);
          break;
        case CatalogType.profiles:
          final result = await ref
              .read(profilesRepositoryProvider)
              .synchronize();
          _update(
            type,
            status: CatalogSyncStatus.synchronized,
            records: result.records,
            synchronizedAt: result.synchronizedAt,
          );
          state = state.copyWith(lastSynchronization: result.synchronizedAt);
          break;
        case CatalogType.orderTypes:
          final result = await ref
              .read(orderTypesRepositoryProvider)
              .synchronize();
          _update(
            type,
            status: CatalogSyncStatus.synchronized,
            records: result.records,
            synchronizedAt: result.synchronizedAt,
          );
          state = state.copyWith(lastSynchronization: result.synchronizedAt);
          break;
        case CatalogType.statuses:
          final result = await ref
              .read(statusesRepositoryProvider)
              .synchronize();
          _update(
            type,
            status: CatalogSyncStatus.synchronized,
            records: result.records,
            synchronizedAt: result.synchronizedAt,
          );
          state = state.copyWith(lastSynchronization: result.synchronizedAt);
          break;
        case CatalogType.clients:
          final result = await ref
              .read(clientsSyncRepositoryProvider)
              .synchronize();
          _update(
            type,
            status: CatalogSyncStatus.synchronized,
            records: result.records,
            synchronizedAt: result.synchronizedAt,
          );
          state = state.copyWith(lastSynchronization: result.synchronizedAt);
          break;
        case CatalogType.users:
          final result = await ref.read(usersRepositoryProvider).synchronize();
          _update(
            type,
            status: CatalogSyncStatus.synchronized,
            records: result.records,
            synchronizedAt: result.synchronizedAt,
          );
          state = state.copyWith(lastSynchronization: result.synchronizedAt);
          break;
      }
      return true;
    } catch (error) {
      lastError = error.toString();
      _update(type, status: CatalogSyncStatus.error);
      return false;
    }
  }

  Future<bool> synchronizeAll() async {
    state = state.copyWith(synchronizingAll: true);
    var success = true;
    for (final item in state.catalogs.where((item) => item.endpoint != null)) {
      success = await synchronize(item.type) && success;
    }
    state = state.copyWith(synchronizingAll: false);
    return success;
  }

  Future<void> restoreLocalStatus() async {
    lastError = null;
    try {
      final paymentForms = await ref
          .read(paymentFormsRepositoryProvider)
          .localStatus();
      final paymentMethods = await ref
          .read(paymentMethodsRepositoryProvider)
          .localStatus();
      final profiles = await ref.read(profilesRepositoryProvider).localStatus();
      final orderTypes = await ref
          .read(orderTypesRepositoryProvider)
          .localStatus();
      final statuses = await ref.read(statusesRepositoryProvider).localStatus();
      final clients = await ref
          .read(clientsSyncRepositoryProvider)
          .localStatus();
      final users = await ref.read(usersRepositoryProvider).localStatus();
      _restoreItem(
        CatalogType.paymentForms,
        paymentForms.records,
        paymentForms.synchronizedAt,
      );
      _restoreItem(
        CatalogType.paymentMethods,
        paymentMethods.records,
        paymentMethods.synchronizedAt,
      );
      _restoreItem(
        CatalogType.profiles,
        profiles.records,
        profiles.synchronizedAt,
      );
      _restoreItem(
        CatalogType.orderTypes,
        orderTypes.records,
        orderTypes.synchronizedAt,
      );
      _restoreItem(
        CatalogType.statuses,
        statuses.records,
        statuses.synchronizedAt,
      );
      _restoreItem(
        CatalogType.clients,
        clients.records,
        clients.synchronizedAt,
      );
      _restoreItem(CatalogType.users, users.records, users.synchronizedAt);
      final dates = [
        paymentForms.synchronizedAt,
        paymentMethods.synchronizedAt,
        profiles.synchronizedAt,
        orderTypes.synchronizedAt,
        statuses.synchronizedAt,
        clients.synchronizedAt,
        users.synchronizedAt,
      ].whereType<DateTime>().toList();
      if (dates.isNotEmpty) {
        dates.sort();
        state = state.copyWith(lastSynchronization: dates.last);
      }
    } catch (error) {
      lastError = error.toString();
    }
  }

  void _restoreItem(CatalogType type, int records, DateTime? synchronizedAt) {
    if (records == 0) return;
    _update(
      type,
      status: CatalogSyncStatus.synchronized,
      records: records,
      synchronizedAt: synchronizedAt,
    );
  }

  void _update(
    CatalogType type, {
    required CatalogSyncStatus status,
    int? records,
    DateTime? synchronizedAt,
  }) {
    state = state.copyWith(
      catalogs: [
        for (final item in state.catalogs)
          if (item.type == type)
            item.copyWith(
              status: status,
              records: records,
              synchronizedAt: synchronizedAt,
            )
          else
            item,
      ],
    );
  }
}

final catalogSyncControllerProvider =
    NotifierProvider<CatalogSyncController, CatalogSyncState>(
      CatalogSyncController.new,
    );
