import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/core/storage/secure_storage_provider.dart';
import 'package:kommerze_mobile/features/license/domain/entities/stored_license.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_details.dart';
import 'package:kommerze_mobile/features/license/domain/entities/stored_branch.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_activation_result.dart';
import 'package:sqflite/sqflite.dart';

class LicenseLocalDataSource {
  static const _secureLicenseKey = 'active_license_key';

  final AppDatabase database;
  final FlutterSecureStorage secureStorage;

  const LicenseLocalDataSource(this.database, this.secureStorage);

  Future<void> saveActiveLicense({
    required String machineId,
    required String licenseKey,
    required String deviceName,
    required LicenseActivationResult activation,
  }) async {
    final branch = activation.branch;
    final signature = activation.signature;
    if (branch == null || signature == null || signature.isEmpty) {
      throw const FormatException(
        'La activación no contiene sucursal o firma.',
      );
    }
    final license = branch.license;
    final now = DateTime.now().toUtc().toIso8601String();
    final secureKey = license.licenseKey.isEmpty
        ? licenseKey
        : license.licenseKey;
    await secureStorage.write(key: _secureLicenseKey, value: secureKey);

    try {
      final db = await database.instance;
      await db.transaction((transaction) async {
        await transaction.insert('licenses', {
          'id': 1,
          'machine_id': license.machineId.isEmpty
              ? machineId.trim()
              : license.machineId,
          'device_name': license.deviceName.isEmpty
              ? deviceName.trim()
              : license.deviceName,
          'license_key_hint': _keyHint(secureKey),
          'license_guid': license.guid,
          'license_api_id': license.id,
          'validity_months': license.validityMonths,
          'app_version': license.appVersion,
          'expires_at': license.expirationDate?.toUtc().toIso8601String(),
          'is_active': 1,
          'activated_at':
              license.activationDate?.toUtc().toIso8601String() ?? now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await transaction.insert('sucursales', {
          'id': branch.id,
          'empresa_id': branch.companyId,
          'lista_precio_id': branch.priceListId,
          'licencia_id': branch.licenseId,
          'clave': branch.code,
          'nombre_sucursal': branch.name,
          'calle': branch.street,
          'exterior': branch.exterior,
          'interior': branch.interior,
          'colonia': branch.neighborhood,
          'ciudad': branch.city,
          'estado': branch.state,
          'codigo_postal': branch.postalCode,
          'telefono': branch.phone,
          'correo': branch.email,
          'serie_cfdi': branch.cfdiSeries,
          'comision_ventas': branch.salesCommission,
          'valor_inventario': branch.inventoryValue,
          'guid': branch.guid,
          'signature': signature,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } catch (_) {
      await secureStorage.delete(key: _secureLicenseKey);
      rethrow;
    }
  }

  Future<StoredLicense?> getActiveLicense() async {
    final db = await database.instance;
    final rows = await db.query(
      'licenses',
      where: 'id = ? AND is_active = ?',
      whereArgs: const [1, 1],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final key = await secureStorage.read(key: _secureLicenseKey);
    if (key == null || key.isEmpty) return null;
    final license = StoredLicense.fromMap(rows.first);
    return license.isExpired ? null : license;
  }

  Future<LicenseDetails?> getLicenseDetails() async {
    final license = await getActiveLicense();
    if (license == null) return null;

    final db = await database.instance;
    final rows = await db.query('sucursales', limit: 1);
    if (rows.isEmpty) return null;
    return LicenseDetails(
      license: license,
      branch: StoredBranch.fromMap(rows.first),
    );
  }

  Future<void> clear() async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      await transaction.delete('sucursales');
      await transaction.delete('licenses');
    });
    await secureStorage.delete(key: _secureLicenseKey);
  }

  String _keyHint(String key) {
    final normalized = key.trim();
    if (normalized.length <= 4) return '••••';
    return '••••${normalized.substring(normalized.length - 4)}';
  }
}

final licenseLocalDataSourceProvider = Provider<LicenseLocalDataSource>((ref) {
  return LicenseLocalDataSource(
    ref.read(appDatabaseProvider),
    ref.read(secureStorageProvider),
  );
});
