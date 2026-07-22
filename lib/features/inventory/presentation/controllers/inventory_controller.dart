import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/inventory/data/repositories/inventory_repository.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';

class InventoryController extends AsyncNotifier<List<InventoryItem>> {
  @override
  Future<List<InventoryItem>> build() {
    return ref.read(inventoryRepositoryProvider).load();
  }

  Future<bool> syncPrices() =>
      _run(() => ref.read(inventoryRepositoryProvider).syncPrices());

  Future<bool> recoverInventory() =>
      _run(() => ref.read(inventoryRepositoryProvider).recoverInventory());

  Future<bool> backupInventory() =>
      _run(() => ref.read(inventoryRepositoryProvider).backupInventory());

  Future<bool> _run(Future<List<InventoryItem>> Function() action) async {
    state = const AsyncLoading<List<InventoryItem>>();
    final result = await AsyncValue.guard(action);
    state = result;
    return !result.hasError;
  }
}

final inventoryControllerProvider =
    AsyncNotifierProvider<InventoryController, List<InventoryItem>>(
      InventoryController.new,
    );
