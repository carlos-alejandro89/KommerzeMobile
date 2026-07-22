import 'package:kommerze_mobile/features/collections/domain/entities/collection_models.dart';

CollectionPreview allocateCollectionPayment(
  List<ReceivableAccount> accounts,
  double receivedAmount,
) {
  var remaining = receivedAmount.isFinite && receivedAmount > 0
      ? receivedAmount
      : 0.0;
  final allocations = <CollectionAllocation>[];
  for (final account in accounts) {
    if (remaining <= .001) break;
    if (account.blocked || account.balance <= .001) continue;
    final applied = remaining > account.balance ? account.balance : remaining;
    allocations.add(
      CollectionAllocation(
        accountGuid: account.accountGuid,
        orderGuid: account.orderGuid,
        folio: account.folio,
        dueAt: account.dueAt,
        previousBalance: account.balance,
        appliedAmount: applied,
      ),
    );
    remaining -= applied;
  }
  final applied = allocations.fold<double>(
    0,
    (sum, item) => sum + item.appliedAmount,
  );
  return CollectionPreview(
    receivedAmount: receivedAmount,
    appliedAmount: applied,
    creditBalance: remaining.clamp(0, double.infinity),
    allocations: allocations,
  );
}
