import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/shared_prefs_provider.dart';

enum InventorySource {
  local('Inventario local'),
  cloud('Inventario Cloud');

  final String label;
  const InventorySource(this.label);
}

class InventorySourceController extends Notifier<InventorySource> {
  static const _storageKey = 'inventory_source';

  @override
  InventorySource build() {
    final saved = ref.read(sharedPrefsProvider).getString(_storageKey);
    return InventorySource.values.firstWhere(
      (source) => source.name == saved,
      orElse: () => InventorySource.local,
    );
  }

  Future<void> save(InventorySource source) async {
    await ref.read(sharedPrefsProvider).setString(_storageKey, source.name);
    state = source;
  }
}

final inventorySourceControllerProvider =
    NotifierProvider<InventorySourceController, InventorySource>(
      InventorySourceController.new,
    );
