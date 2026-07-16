import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kommerze_mobile/core/storage/secure_storage_provider.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentity {
  final String id;
  final String name;

  const DeviceIdentity({required this.id, required this.name});
}

abstract interface class DeviceIdentityService {
  Future<DeviceIdentity> load();
}

class PlatformDeviceIdentityService implements DeviceIdentityService {
  static const _fallbackIdKey = 'device_installation_id';
  final DeviceInfoPlugin _deviceInfo;
  final FlutterSecureStorage _storage;

  PlatformDeviceIdentityService(this._deviceInfo, this._storage);

  @override
  Future<DeviceIdentity> load() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        return DeviceIdentity(
          id: await _fallbackId(),
          name: _deviceName(
            '${info.brand} ${info.model}',
            'Dispositivo Android',
          ),
        );
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfo.iosInfo;
        return DeviceIdentity(
          id:
              _usableIdentifier(info.identifierForVendor) ??
              await _fallbackId(),
          name: _deviceName(info.name, info.model),
        );
      }
    } catch (_) {
      // Usa la identidad local cuando el sistema no expone datos del equipo.
    }

    return DeviceIdentity(id: await _fallbackId(), name: 'Mi dispositivo');
  }

  String _deviceName(String value, String fallback) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? fallback : normalized;
  }

  String? _usableIdentifier(String? value) {
    final normalized = value?.trim();
    if (normalized == null ||
        normalized.isEmpty ||
        normalized.toLowerCase() == 'unknown') {
      return null;
    }
    return normalized;
  }

  Future<String> _fallbackId() async {
    final generated = const Uuid().v4();
    try {
      final stored = await _storage.read(key: _fallbackIdKey);
      if (stored != null && stored.isNotEmpty) return stored;
      await _storage.write(key: _fallbackIdKey, value: generated);
    } catch (_) {
      // En pruebas o plataformas sin almacenamiento seguro conserva el fallback.
    }
    return generated;
  }
}

final deviceIdentityServiceProvider = Provider<DeviceIdentityService>((ref) {
  return PlatformDeviceIdentityService(
    DeviceInfoPlugin(),
    ref.read(secureStorageProvider),
  );
});
