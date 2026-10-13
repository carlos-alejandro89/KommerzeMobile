import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/shared_prefs_provider.dart';

enum DeviceType {
  smartphone('Smartphone'),
  pda('PDA');

  final String label;
  const DeviceType(this.label);
}

class DeviceTypeController extends Notifier<DeviceType> {
  static const _storageKey = 'device_type';

  @override
  DeviceType build() {
    final saved = ref.read(sharedPrefsProvider).getString(_storageKey);
    return DeviceType.values.firstWhere(
      (type) => type.name == saved,
      orElse: () => DeviceType.smartphone,
    );
  }

  Future<void> save(DeviceType type) async {
    await ref.read(sharedPrefsProvider).setString(_storageKey, type.name);
    state = type;
  }
}

final deviceTypeControllerProvider =
    NotifierProvider<DeviceTypeController, DeviceType>(
      DeviceTypeController.new,
    );
