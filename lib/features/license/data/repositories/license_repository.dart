import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/license/data/datasources/license_api.dart';
import 'package:kommerze_mobile/features/license/data/datasources/license_local_data_source.dart';
import 'package:kommerze_mobile/features/license/data/models/license_activation_request_dto.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_activation_result.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_details.dart';
import 'package:kommerze_mobile/core/storage/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseRepository {
  final LicenseApi api;
  final LicenseLocalDataSource local;
  final SharedPreferences preferences;

  const LicenseRepository(this.api, this.local, this.preferences);

  Future<LicenseActivationResult> activate({
    required String machineId,
    required String licenseKey,
    required String deviceName,
  }) async {
    final normalizedLicenseKey =
        LicenseActivationRequestDto.normalizeLicenseKey(licenseKey);
    final result = await api.activate(
      LicenseActivationRequestDto(
        machineId: machineId,
        licenseKey: normalizedLicenseKey,
        deviceName: deviceName,
      ),
    );
    if (result.success) {
      await local.saveActiveLicense(
        machineId: machineId,
        licenseKey: normalizedLicenseKey,
        deviceName: deviceName,
        activation: result,
      );
      await preferences.setString(
        'inventory_source',
        result.branch?.cloudInventory == true ? 'cloud' : 'local',
      );
    }
    return result;
  }

  Future<bool> hasActiveLicense() async {
    return await local.getActiveLicense() != null;
  }

  Future<LicenseDetails?> getLicenseDetails() => local.getLicenseDetails();
}

final licenseRepositoryProvider = Provider<LicenseRepository>((ref) {
  return LicenseRepository(
    ref.watch(licenseApiProvider),
    ref.read(licenseLocalDataSourceProvider),
    ref.read(sharedPrefsProvider),
  );
});
