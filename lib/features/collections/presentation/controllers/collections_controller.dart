import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/collections/data/repositories/collections_repository.dart';
import 'package:kommerze_mobile/features/collections/domain/entities/collection_models.dart';

final collectionsDashboardProvider = FutureProvider<CollectionDashboard>((
  ref,
) async {
  final repository = ref.read(collectionsRepositoryProvider);
  try {
    await repository.syncPending();
  } catch (_) {
    // El dashboard local sigue disponible aun sin conexión.
  }
  return repository.getDashboard();
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
