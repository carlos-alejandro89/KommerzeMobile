class UsuarioEntity {
  final String id;
  final String name;
  final String email;
  final String accessToken;
  final String refreshToken;
  final String expiresIn;
  final List<String> permissions;
  final String profile;
  final String userGuid;

  UsuarioEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.permissions,
    this.profile = '',
    this.userGuid = '',
  });

  // we need to can create a updated copies when token change
  UsuarioEntity copyWith({String? accessToken, String? refreshToken}) {
    return UsuarioEntity(
      id: id,
      name: name,
      email: email,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresIn: expiresIn,
      permissions: permissions,
      profile: profile,
      userGuid: userGuid,
    );
  }
}
