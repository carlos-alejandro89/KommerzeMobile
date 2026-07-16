// TODO: Implementar controlador de autenticación con Riverpod.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/shared_prefs_provider.dart';
import 'package:kommerze_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:kommerze_mobile/features/auth/domain/entities/usuario_entity.dart';

class AuthController extends AsyncNotifier<UsuarioEntity?> {
  @override
  FutureOr<UsuarioEntity?> build() async {
    final repo = ref.read(authRepoProvider);
    final prefs = ref.read(sharedPrefsProvider);

    debugPrint('🔑 Llaves actuales en SharedPreferences: ${prefs.getKeys()}');
    try {
      final usuarioSaved = await repo.getSession();

      debugPrint('🕵️‍♂️ 4. Resultado final entregado al Jefe: $usuarioSaved');
      return usuarioSaved;
    } catch (e) {
      debugPrint('🚨 ERROR CRÍTICO AL LEER MEMORIA: $e');
      return null;
    }
  }

  Future<void> login({required String user, required String password}) async {
    state = const AsyncLoading();

    try {
      final repo = ref.read(authRepoProvider);

      final usuario = await repo.login(user: user, password: password);

      state = AsyncData(usuario);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      debugPrint(e.toString());
    }
  }

  Future<void> logout() async {
    state = const AsyncLoading();

    debugPrint("cerrando sesion...");
    await ref.read(authRepoProvider).cerrarSesion();

    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider(AuthController.new);
