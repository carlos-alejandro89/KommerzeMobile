class LoanSyncBatch {
  final List<Map<String, Object?>> loans;
  final List<Map<String, Object?>> applications;

  const LoanSyncBatch({required this.loans, required this.applications});

  factory LoanSyncBatch.fromJson(Map<String, dynamic> json) => LoanSyncBatch(
    loans: _maps(json, 'prestamos'),
    applications: _maps(json, 'aplicaciones'),
  );

  bool get isEmpty => loans.isEmpty && applications.isEmpty;
  int get length => loans.length + applications.length;

  Map<String, Object?> toJson() => {
    'prestamos': loans,
    'aplicaciones': applications,
  };
}

class LoanSyncResult {
  final List<String> loans;
  final List<String> applications;

  const LoanSyncResult({required this.loans, required this.applications});

  factory LoanSyncResult.fromJson(Map<String, dynamic> json) => LoanSyncResult(
    loans: _strings(json, 'prestamos'),
    applications: _strings(json, 'aplicaciones'),
  );

  int get length => loans.length + applications.length;
}

class LoansRecoveryResult {
  final int received;
  final int saved;
  final int preservedPending;
  final int omittedMissingReferences;

  const LoansRecoveryResult({
    required this.received,
    required this.saved,
    required this.preservedPending,
    required this.omittedMissingReferences,
  });
}

List<Map<String, Object?>> _maps(Map<String, dynamic> json, String key) {
  final value = json[key] ?? json[_pascal(key)];
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

List<String> _strings(Map<String, dynamic> json, String key) {
  final value = json[key] ?? json[_pascal(key)];
  return value is List
      ? value.map((item) => item.toString()).toList(growable: false)
      : const [];
}

String _pascal(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
