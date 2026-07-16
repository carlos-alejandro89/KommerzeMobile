// TODO: Implementar repositorio de autenticación (orquesta API + Local).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/auth/data/datasources/auth_api.dart';
import 'package:kommerze_mobile/features/auth/data/datasources/auth_local.dart';
import 'package:kommerze_mobile/features/auth/data/models/usuario_dto.dart';
import 'package:kommerze_mobile/features/auth/domain/entities/usuario_entity.dart';

class AuthRepository {
  final AuthApi api;
  final AuthLocal local;

  AuthRepository(this.api, this.local);

  Future<UsuarioEntity?> login({
    required String user,
    required String password,
  }) async {
    final response = await api.login(email: user, password: password);
    final usuario = UsuarioDto.fromLoginResponse(response);

    if (usuario.accessToken.isEmpty) {
      throw const AuthApiException('El servidor no devolvió un token válido.');
    }

    await local.saveToken(token: usuario.accessToken);
    await local.saveUser(usuario.toEntity());

    return usuario.toEntity();
  }

  Future<void> cerrarSesion() async {
    await local.deleteToken();
    await local.deleteUser();
  }

  Future<UsuarioEntity?> getSession() async {
    final token = await local.readToken();
    if (token == null || token.isEmpty) return null;

    final userEntity = local.readUser();
    if (userEntity == null) {
      await local.deleteToken();
      return null;
    }
    return userEntity.copyWith(accessToken: token);
  }
}

// Provider
final authRepoProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(authApiProvider), ref.read(authLocalProvider));
});
