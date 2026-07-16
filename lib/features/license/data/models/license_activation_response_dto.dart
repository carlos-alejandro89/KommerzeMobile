import 'package:kommerze_mobile/features/license/domain/entities/branch_info.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_activation_result.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_info.dart';

class LicenseActivationResponseDto {
  const LicenseActivationResponseDto._();

  static LicenseActivationResult fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true;
    final message =
        json['mensaje']?.toString() ??
        (success
            ? 'Licencia activada correctamente.'
            : 'No fue posible activar la licencia.');
    if (!success) {
      return LicenseActivationResult(success: false, message: message);
    }

    final data = _map(json['data']);
    final branchJson = _map(data['sucursal']);
    final licenseJson = _map(branchJson['licencia']);
    if (branchJson.isEmpty || licenseJson.isEmpty) {
      return const LicenseActivationResult(
        success: false,
        message: 'La respuesta de activación está incompleta.',
      );
    }

    final license = LicenseInfo(
      id: _integer(licenseJson['id']),
      guid: _string(licenseJson['guid']),
      deviceName: _string(licenseJson['nombreDispositivo']),
      licenseKey: _string(licenseJson['licenciaKey']),
      appVersion: _string(licenseJson['appVersion']),
      machineId: _string(licenseJson['machineId']),
      validityMonths: _integer(licenseJson['numMesesVigencia']),
      activationDate: DateTime.tryParse(
        _string(licenseJson['fechaActivacion']),
      ),
      expirationDate: DateTime.tryParse(
        _string(licenseJson['fechaExpiracion']),
      ),
    );

    final branch = BranchInfo(
      id: _integer(branchJson['id']),
      companyId: _integer(branchJson['empresaId']),
      priceListId: _nullableInteger(branchJson['listaPrecioId']),
      licenseId: _integer(branchJson['licenciaId']),
      code: _string(branchJson['clave']),
      name: _string(branchJson['nombreSucursal']),
      street: _string(branchJson['calle']),
      exterior: _string(branchJson['exterior']),
      interior: branchJson['interior']?.toString(),
      neighborhood: _string(branchJson['colonia']),
      city: _string(branchJson['ciudad']),
      state: _string(branchJson['estado']),
      postalCode: _string(branchJson['codigoPostal']),
      phone: _string(branchJson['telefono']),
      email: _string(branchJson['correo']),
      cfdiSeries: _string(branchJson['serieCfdi']),
      salesCommission: _decimal(branchJson['comisionVentas']),
      inventoryValue: _decimal(branchJson['valorInventario']),
      guid: _string(branchJson['guid']),
      license: license,
    );

    return LicenseActivationResult(
      success: true,
      message: message,
      branch: branch,
      signature: _string(data['signature']),
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  static String _string(Object? value) => value?.toString() ?? '';

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

  static int? _nullableInteger(Object? value) {
    if (value == null) return null;
    return _integer(value);
  }

  static double _decimal(Object? value) =>
      value is num ? value.toDouble() : double.tryParse(_string(value)) ?? 0;
}
