import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthApiFake {
  Future<Map<String, dynamic>> loginFake({
    required String user,
    required String password,
  }) async {
    await Future.delayed(const Duration(seconds: 4));

    if (user.isEmpty || password.isEmpty) {
      throw Exception("El campo de usuario o contraseña esta vacio");
    }

    return <String, dynamic>{
      "access_token": "eyJhGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake_token_abc123",
      "expires_in": 3600,
      "refresh_token": "def456_fake_refresh_token",
      "token_type": "Bearer",
      "user": {
        "active": true,
        "created_at": "2026-04-25T07:55:00Z",
        "email": user,
        "groups": ["vendedores", "ruta_sur"],
        "id": 99,
        "name": "Carlos Arturo Alejandro",
        "permissions": ["cobrar", "ver_clientes"],
        "updated_at": "2026-04-25T07:55:00Z",
      },
    };
  }
}

// Provider
final authApiFakeProvider = Provider<AuthApiFake>((ref) {
  return AuthApiFake();
});
