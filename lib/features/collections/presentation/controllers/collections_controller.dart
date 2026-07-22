import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/collections/data/repositories/collections_repository.dart';
import 'package:kommerze_mobile/features/collections/domain/entities/collection_models.dart';

final collectionsDashboardProvider = FutureProvider<CollectionDashboard>((ref) {
  return ref.read(collectionsRepositoryProvider).getDashboard();
});

final collectionClientDetailProvider =
    FutureProvider.family<CollectionClientDetail, String>((ref, clientGuid) {
      return ref
          .read(collectionsRepositoryProvider)
          .getClientDetail(clientGuid);
    });

final collectionPaymentFormsProvider = FutureProvider<List<PaymentFormOption>>((
  ref,
) {
  return ref.read(collectionsRepositoryProvider).getPaymentForms();
});

void invalidateCollections(Ref ref, [String? clientGuid]) {
  ref.invalidate(collectionsDashboardProvider);
  if (clientGuid != null) {
    ref.invalidate(collectionClientDetailProvider(clientGuid));
  }
}
