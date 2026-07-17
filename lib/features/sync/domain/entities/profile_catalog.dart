class ProfileCatalog {
  final int id;
  final String name;
  final String guid;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const ProfileCatalog({
    required this.id,
    required this.name,
    required this.guid,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });
}
