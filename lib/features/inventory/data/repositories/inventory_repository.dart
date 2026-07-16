import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/inventory/data/datasources/inventory_api.dart';
import 'package:kommerze_mobile/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';

class InventoryRepository {
  final InventoryApi api;
  final InventoryLocalDataSource local;

  const InventoryRepository(this.api, this.local);

  Future<List<InventoryItem>> load() async {
    if (!await local.hasItems()) {
      final guid = await _branchGuid();
      final prices = await api.getPrices(guid);
      await local.saveInitialPrices(prices);
    }
    return local.getItems();
  }

  Future<List<InventoryItem>> syncPrices() async {
    final prices = await api.getPrices(await _branchGuid());
    await local.syncPrices(prices);
    return local.getItems();
  }

  Future<List<InventoryItem>> recoverInventory() async {
    final backup = await api.recoverInventory(await _branchGuid());
    await local.restoreStock(backup);
    return local.getItems();
  }

  Future<String> _branchGuid() async {
    final guid = await local.getBranchGuid();
    if (guid == null || guid.isEmpty) {
      throw const InventoryException(
        'No existe una sucursal activa para consultar el inventario.',
      );
    }
    return guid;
  }
}

class InventoryException implements Exception {
  final String message;
  const InventoryException(this.message);
  @override
  String toString() => message;
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    ref.read(inventoryApiProvider),
    ref.read(inventoryLocalDataSourceProvider),
  );
});
