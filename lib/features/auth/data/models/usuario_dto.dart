import 'package:kommerze_mobile/features/auth/domain/entities/usuario_entity.dart';

class UsuarioDto extends UsuarioEntity {
  UsuarioDto({
    required super.id,
    required super.name,
    required super.email,
    required super.accessToken,
    required super.refreshToken,
    required super.expiresIn,
    required super.permissions,
    required super.profile,
    required super.userGuid,
  });

  factory UsuarioDto.fromLoginResponse(Map<String, dynamic> response) {
    final rawData = response['data'];
    if (rawData is! Map) {
      throw const FormatException('La respuesta no contiene datos de usuario.');
    }
    final data = Map<String, dynamic>.from(rawData);
    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const FormatException('La respuesta no contiene un token válido.');
    }

    return UsuarioDto(
      id: data['usuarioGuid']?.toString() ?? '',
      userGuid: data['usuarioGuid']?.toString() ?? '',
      name: data['nombreCompleto']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      profile: data['perfil']?.toString() ?? '',
      accessToken: token,
      refreshToken: '',
      expiresIn: '',
      permissions: const [],
    );
  }

  factory UsuarioDto.fromJson(Map<String, dynamic> json) {
    return UsuarioDto(
      id: json['id']?.toString() ?? json['userGuid']?.toString() ?? '',
      userGuid: json['userGuid']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      profile: json['profile']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresIn: json['expiresIn']?.toString() ?? '',
      permissions: List<String>.from(json['permissions'] ?? const []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userGuid': userGuid,
    'name': name,
    'email': email,
    'profile': profile,
    'refreshToken': refreshToken,
    'expiresIn': expiresIn,
    'permissions': permissions,
  };

  UsuarioEntity toEntity() => UsuarioEntity(
    id: id,
    userGuid: userGuid,
    name: name,
    email: email,
    profile: profile,
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresIn: expiresIn,
    permissions: permissions,
  );

  factory UsuarioDto.fromEntity(UsuarioEntity user) => UsuarioDto(
    id: user.id,
    userGuid: user.userGuid,
    name: user.name,
    email: user.email,
    profile: user.profile,
    accessToken: user.accessToken,
    refreshToken: user.refreshToken,
    expiresIn: user.expiresIn,
    permissions: user.permissions,
  );

  @override
  String toString() => 'UsuarioEntity(id: $id, name: $name, email: $email)';
}
