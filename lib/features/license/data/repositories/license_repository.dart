import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/license/data/datasources/license_api.dart';
import 'package:kommerze_mobile/features/license/data/datasources/license_local_data_source.dart';
import 'package:kommerze_mobile/features/license/data/models/license_activation_request_dto.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_activation_result.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_details.dart';

class LicenseRepository {
  final LicenseApi api;
  final LicenseLocalDataSource local;

  const LicenseRepository(this.api, this.local);

  Future<LicenseActivationResult> activate({
    required String machineId,
    required String licenseKey,
    required String deviceName,
  }) async {
    final result = await api.activate(
      LicenseActivationRequestDto(
        machineId: machineId,
        licenseKey: licenseKey,
        deviceName: deviceName,
      ),
    );
    if (result.success) {
      await local.saveActiveLicense(
        machineId: machineId,
        licenseKey: licenseKey,
        deviceName: deviceName,
        activation: result,
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
    ref.read(licenseApiProvider),
    ref.read(licenseLocalDataSourceProvider),
  );
});
