class OrderTypeCatalog {
  final int id;
  final String name;
  final String description;
  final String? icon;
  final String guid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const OrderTypeCatalog({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.guid,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });
}
