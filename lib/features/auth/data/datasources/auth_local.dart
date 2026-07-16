import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kommerze_mobile/core/storage/secure_storage_provider.dart';
import 'package:kommerze_mobile/core/storage/shared_prefs_provider.dart';
import 'package:kommerze_mobile/features/auth/data/models/usuario_dto.dart';
import 'package:kommerze_mobile/features/auth/domain/entities/usuario_entity.dart';

class AuthLocal {
  final FlutterSecureStorage storage;
  final SharedPreferences sharedPrefs;

  AuthLocal(this.storage, this.sharedPrefs);

  Future<void> saveToken({required String token}) async {
    await storage.write(key: 'token', value: token);
  }

  Future<String?> readToken() async {
    return await storage.read(key: 'token');
  }

  Future<void> deleteToken() async {
    await storage.delete(key: 'token');
  }

  Future<void> saveUser(UsuarioEntity user) async {
    final userDto = UsuarioDto.fromEntity(user);
    final String jsonUser = jsonEncode(userDto.toJson());

    await sharedPrefs.setString('user_data', jsonUser);
  }

  UsuarioEntity? readUser() {
    final String? jsonUsuario = sharedPrefs.getString('user_data');

    if (jsonUsuario != null) {
      try {
        final usuarioDto = UsuarioDto.fromJson(jsonDecode(jsonUsuario));

        return usuarioDto.toEntity();
      } catch (e) {
        debugPrint('No fue posible restaurar el usuario: $e');
      }
    }

    return null;
  }

  Future<void> deleteUser() async {
    await sharedPrefs.remove('user_data');
  }
}

// Provider
final authLocalProvider = Provider<AuthLocal>((ref) {
  return AuthLocal(
    ref.read(secureStorageProvider),
    ref.read(sharedPrefsProvider),
  );
});
