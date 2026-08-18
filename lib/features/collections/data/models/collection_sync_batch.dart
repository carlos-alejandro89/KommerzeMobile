class CollectionSyncBatch {
  final List<Map<String, Object?>> accounts;
  final List<Map<String, Object?>> collections;
  final List<Map<String, Object?>> paymentForms;
  final List<Map<String, Object?>> applications;

  const CollectionSyncBatch({
    required this.accounts,
    required this.collections,
    required this.paymentForms,
    required this.applications,
  });

  factory CollectionSyncBatch.fromJson(Map<String, dynamic> json) {
    List<Map<String, Object?>> maps(String key) {
      final pascal = key.isEmpty
          ? key
          : '${key[0].toUpperCase()}${key.substring(1)}';
      final value = json[key] ?? json[pascal];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map(
            (item) => Map<String, Object?>.from(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
    }

    return CollectionSyncBatch(
      accounts: maps('cuentasPorCobrar'),
      collections: maps('cobros'),
      paymentForms: maps('formasPago'),
      applications: maps('aplicaciones'),
    );
  }

  bool get isEmpty =>
      accounts.isEmpty &&
      collections.isEmpty &&
      paymentForms.isEmpty &&
      applications.isEmpty;

  int get length =>
      accounts.length +
      collections.length +
      paymentForms.length +
      applications.length;

  Map<String, Object?> toJson() => {
    'cuentasPorCobrar': accounts,
    'cobros': collections,
    'formasPago': paymentForms,
    'aplicaciones': applications,
  };
}

class CollectionsRecoveryResult {
  final int received;
  final int saved;
  final int preservedPending;
  final int omittedMissingReferences;

  const CollectionsRecoveryResult({
    required this.received,
    required this.saved,
    required this.preservedPending,
    required this.omittedMissingReferences,
  });
}

class CollectionSyncResult {
  final List<String> accounts;
  final List<String> collections;
  final List<String> paymentForms;
  final List<String> applications;

  const CollectionSyncResult({
    required this.accounts,
    required this.collections,
    required this.paymentForms,
    required this.applications,
  });

  factory CollectionSyncResult.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) {
      final value = json[key] ?? json[_pascal(key)];
      return value is List
          ? value.map((item) => item.toString()).toList(growable: false)
          : const [];
    }

    return CollectionSyncResult(
      accounts: strings('cuentasPorCobrar'),
      collections: strings('cobros'),
      paymentForms: strings('formasPago'),
      applications: strings('aplicaciones'),
    );
  }

  int get length =>
      accounts.length +
      collections.length +
      paymentForms.length +
      applications.length;

  static String _pascal(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
