import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/license/data/repositories/license_repository.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_activation_result.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_details.dart';

class LicenseActivationController
    extends AsyncNotifier<LicenseActivationResult?> {
  @override
  FutureOr<LicenseActivationResult?> build() => null;

  Future<void> activate({
    required String machineId,
    required String licenseKey,
    required String deviceName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(licenseRepositoryProvider)
          .activate(
            machineId: machineId,
            licenseKey: licenseKey,
            deviceName: deviceName,
          ),
    );
    if (state.value?.success == true) {
      ref.invalidate(licenseStatusControllerProvider);
      ref.invalidate(licenseDetailsProvider);
    }
  }
}

final licenseActivationControllerProvider =
    AsyncNotifierProvider<
      LicenseActivationController,
      LicenseActivationResult?
    >(LicenseActivationController.new);

class LicenseStatusController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref.read(licenseRepositoryProvider).hasActiveLicense();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(licenseRepositoryProvider).hasActiveLicense(),
    );
  }
}

final licenseStatusControllerProvider =
    AsyncNotifierProvider<LicenseStatusController, bool>(
      LicenseStatusController.new,
    );

final licenseDetailsProvider = FutureProvider<LicenseDetails?>((ref) {
  return ref.read(licenseRepositoryProvider).getLicenseDetails();
});
