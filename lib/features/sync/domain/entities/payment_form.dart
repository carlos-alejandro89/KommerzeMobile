class PaymentForm {
  final int id;
  final String key;
  final String description;
  final bool isActive;
  final String guid;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const PaymentForm({
    required this.id,
    required this.key,
    required this.description,
    required this.isActive,
    required this.guid,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });
}
