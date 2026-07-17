enum CatalogType {
  paymentForms,
  paymentMethods,
  profiles,
  users,
  clients,
  orderTypes,
  statuses,
}

enum CatalogSyncStatus { pending, syncing, synchronized, error }

class CatalogSyncItem {
  final CatalogType type;
  final String title;
  final String description;
  final CatalogSyncStatus status;
  final int records;
  final DateTime? synchronizedAt;
  final String? endpoint;

  const CatalogSyncItem({
    required this.type,
    required this.title,
    required this.description,
    this.status = CatalogSyncStatus.pending,
    this.records = 0,
    this.synchronizedAt,
    this.endpoint,
  });

  CatalogSyncItem copyWith({
    CatalogSyncStatus? status,
    int? records,
    DateTime? synchronizedAt,
    String? endpoint,
  }) => CatalogSyncItem(
    type: type,
    title: title,
    description: description,
    status: status ?? this.status,
    records: records ?? this.records,
    synchronizedAt: synchronizedAt ?? this.synchronizedAt,
    endpoint: endpoint ?? this.endpoint,
  );
}
