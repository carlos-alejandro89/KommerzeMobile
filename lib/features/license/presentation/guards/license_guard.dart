import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/features/license/presentation/controllers/license_activation_controller.dart';

class LicenseGuard {
  LicenseGuard._();

  /// Devuelve `true` cuando la opción puede abrirse. Si no existe una licencia
  /// activa, redirige automáticamente al flujo de activación.
  static Future<bool> ensureActive(BuildContext context, WidgetRef ref) async {
    final active = await ref.read(licenseStatusControllerProvider.future);
    if (!context.mounted) return false;
    if (!active) {
      await context.push(AppConstants.licenseScreenRoute);
      return false;
    }
    return true;
  }
}
