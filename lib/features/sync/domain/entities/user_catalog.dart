class UserCatalog {
  final int id;
  final int profileId;
  final String name;
  final String phone;
  final String email;
  final bool emailConfirmed;
  final String? profileImage;
  final String guid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const UserCatalog({
    required this.id,
    required this.profileId,
    required this.name,
    required this.phone,
    required this.email,
    required this.emailConfirmed,
    required this.profileImage,
    required this.guid,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });
}
