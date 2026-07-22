import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/auth/data/datasources/auth_local.dart';
import 'package:kommerze_mobile/features/collections/data/datasources/collections_local_data_source.dart';
import 'package:kommerze_mobile/features/collections/domain/entities/collection_models.dart';

class CollectionsRepository {
  final CollectionsLocalDataSource local;
  final AuthLocal authLocal;

  const CollectionsRepository(this.local, this.authLocal);

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
  }) {
    final user = authLocal.readUser();
    if (user == null) {
      throw const CollectionsLocalException(
        'No fue posible identificar al usuario de la sesión.',
      );
    }
    return local.createCollection(
      clientGuid: clientGuid,
      payments: payments,
      userGuid: user.userGuid.isNotEmpty ? user.userGuid : user.id,
      userName: user.name,
    );
  }

  Future<void> setAccountBlocked(String accountGuid, bool blocked) =>
      local.setAccountBlocked(accountGuid, blocked);

  Future<void> cancelCollection(String collectionGuid, String reason) =>
      local.cancelCollection(collectionGuid, reason);
}

final collectionsRepositoryProvider = Provider<CollectionsRepository>((ref) {
  return CollectionsRepository(
    ref.read(collectionsLocalDataSourceProvider),
    ref.read(authLocalProvider),
  );
});
