import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/auth/data/datasources/auth_local.dart';
import 'package:kommerze_mobile/features/collections/data/datasources/collections_local_data_source.dart';
import 'package:kommerze_mobile/features/collections/data/datasources/collections_remote_data_source.dart';
import 'package:kommerze_mobile/features/collections/data/models/collection_sync_batch.dart';
import 'package:kommerze_mobile/features/collections/domain/entities/collection_models.dart';

class CollectionsRepository {
  final CollectionsLocalDataSource local;
  final CollectionsRemoteDataSource remote;
  final AuthLocal authLocal;

  const CollectionsRepository(this.local, this.remote, this.authLocal);

  Future<CollectionDashboard> getDashboard() => local.getDashboard();

  Future<CollectionClientDetail> getClientDetail(String clientGuid) =>
      local.getClientDetail(clientGuid);

  Future<List<PaymentFormOption>> getPaymentForms() => local.getPaymentForms();

  Future<CollectionPreview> preview(
    String clientGuid,
    List<CollectionPaymentInput> payments,
  ) => local.preview(clientGuid, payments);

  Future<CollectionReceipt> register({
    required String clientGuid,
    required List<CollectionPaymentInput> payments,
  }) async {
    final user = authLocal.readUser();
    if (user == null) {
      throw const CollectionsLocalException(
        'No fue posible identificar al usuario de la sesión.',
      );
    }
    final receipt = await local.createCollection(
      clientGuid: clientGuid,
      payments: payments,
      userGuid: user.userGuid.isNotEmpty ? user.userGuid : user.id,
      userName: user.name,
    );
    await _trySyncPending();
    return receipt;
  }

  Future<void> setAccountBlocked(String accountGuid, bool blocked) async {
    await local.setAccountBlocked(accountGuid, blocked);
    await _trySyncPending();
  }

  Future<void> cancelCollection(String collectionGuid, String reason) async {
    await local.cancelCollection(collectionGuid, reason);
    await _trySyncPending();
  }

  Future<CollectionsSyncReport> syncPending() async {
    final batch = await local.getPendingSyncBatch();
    if (batch.isEmpty) {
      return const CollectionsSyncReport(pending: 0, synchronized: 0);
    }
    final result = await remote.synchronize(batch);
    await local.markSyncCompleted(result);
    return CollectionsSyncReport(
      pending: batch.length,
      synchronized: result.length,
    );
  }

  Future<CollectionsRecoveryResult> recoverByActiveBranch() async {
    try {
      await syncPending();
    } catch (_) {
      // La descarga puede continuar: el merge protege cada fila local pendiente.
    }
    final branchGuid = await local.getBranchGuid();
    final snapshot = await remote.recoverByBranch(branchGuid);
    return local.mergeCloudSnapshot(snapshot);
  }

  Future<void> _trySyncPending() async {
    try {
      await syncPending();
    } catch (_) {
      // SQLite conserva sync = 0 para que el siguiente intento reenvíe el lote.
    }
  }
}

class CollectionsSyncReport {
  final int pending;
  final int synchronized;

  const CollectionsSyncReport({
    required this.pending,
    required this.synchronized,
  });
}

final collectionsRepositoryProvider = Provider<CollectionsRepository>((ref) {
  return CollectionsRepository(
    ref.read(collectionsLocalDataSourceProvider),
    ref.watch(collectionsRemoteDataSourceProvider),
    ref.read(authLocalProvider),
  );
});
