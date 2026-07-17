import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:sqflite/sqflite.dart';

class InventoryLocalDataSource {
  final AppDatabase database;

  const InventoryLocalDataSource(this.database);

  Future<String?> getBranchGuid() async {
    final db = await database.instance;
    final rows = await db.query('sucursales', columns: ['guid'], limit: 1);
    return rows.isEmpty ? null : rows.first['guid']?.toString();
  }

  Future<bool> hasItems() async {
    final db = await database.instance;
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM inventario'),
    );
    return (result ?? 0) > 0;
  }

  Future<List<InventoryItem>> getItems() async {
    final db = await database.instance;
    final rows = await db.query(
      'inventario',
      orderBy: 'descripcion COLLATE NOCASE, codigo COLLATE NOCASE',
    );
    return rows.map(InventoryItem.fromMap).toList(growable: false);
  }

  Future<List<InventoryItem>> searchItems({
    String query = '',
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await database.instance;
    final normalized = query.trim();
    final rows = await db.query(
      'inventario',
      where: normalized.isEmpty
          ? null
          : '''codigo LIKE ? OR codigo_barras LIKE ? OR descripcion LIKE ?
               OR nombre_linea LIKE ? OR nombre_marca LIKE ?''',
      whereArgs: normalized.isEmpty ? null : List.filled(5, '%$normalized%'),
      orderBy: 'descripcion COLLATE NOCASE, codigo COLLATE NOCASE',
      limit: limit,
      offset: offset,
    );
    return rows.map(InventoryItem.fromMap).toList(growable: false);
  }

  Future<InventoryItem?> findByBarcode(String barcode) async {
    final db = await database.instance;
    final value = barcode.trim();
    if (value.isEmpty) return null;
    final rows = await db.query(
      'inventario',
      where: 'codigo_barras = ? OR codigo = ?',
      whereArgs: [value, value],
      limit: 1,
    );
    return rows.isEmpty ? null : InventoryItem.fromMap(rows.first);
  }

  Future<void> saveInitialPrices(List<InventoryItem> items) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      final batch = transaction.batch();
      for (final item in items) {
        batch.insert(
          'inventario',
          _map(item, stock: 0),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> syncPrices(List<InventoryItem> items) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      final batch = transaction.batch();
      for (final item in items) {
        batch.rawInsert('''
          INSERT INTO inventario (
            nivel_guid, producto_guid, empaque_guid, codigo, descripcion,
            nivel_empaque, codigo_barras, precio_compra, precio_venta,
            porcentaje_descuento, existencia, nombre_linea, nombre_marca,
            updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
          ON CONFLICT(nivel_guid) DO UPDATE SET
            producto_guid = excluded.producto_guid,
            empaque_guid = excluded.empaque_guid,
            codigo = excluded.codigo,
            descripcion = excluded.descripcion,
            nivel_empaque = excluded.nivel_empaque,
            codigo_barras = excluded.codigo_barras,
            precio_compra = excluded.precio_compra,
            precio_venta = excluded.precio_venta,
            porcentaje_descuento = excluded.porcentaje_descuento,
            nombre_linea = excluded.nombre_linea,
            nombre_marca = excluded.nombre_marca,
            updated_at = excluded.updated_at
        ''', _values(item));
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> restoreStock(List<InventoryItem> items) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      final batch = transaction.batch();
      for (final item in items) {
        batch.rawInsert(
          '''
          INSERT INTO inventario (
            nivel_guid, producto_guid, empaque_guid, codigo, descripcion,
            nivel_empaque, codigo_barras, precio_compra, precio_venta,
            porcentaje_descuento, existencia, nombre_linea, nombre_marca,
            updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(nivel_guid) DO UPDATE SET
            existencia = excluded.existencia,
            updated_at = excluded.updated_at
        ''',
          [..._values(item, includeStock: true)],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Map<String, Object?> _map(InventoryItem item, {required double stock}) {
    return {
      'nivel_guid': item.levelGuid,
      'producto_guid': item.productGuid,
      'empaque_guid': item.packageGuid,
      'codigo': item.code,
      'descripcion': item.description,
      'nivel_empaque': item.packageLevel,
      'codigo_barras': item.barcode,
      'precio_compra': item.purchasePrice,
      'precio_venta': item.salePrice,
      'porcentaje_descuento': item.discountPercentage,
      'existencia': stock,
      'nombre_linea': item.lineName,
      'nombre_marca': item.brandName,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  List<Object?> _values(InventoryItem item, {bool includeStock = false}) {
    return [
      item.levelGuid,
      item.productGuid,
      item.packageGuid,
      item.code,
      item.description,
      item.packageLevel,
      item.barcode,
      item.purchasePrice,
      item.salePrice,
      item.discountPercentage,
      if (includeStock) item.stock,
      item.lineName,
      item.brandName,
      DateTime.now().toUtc().toIso8601String(),
    ];
  }
}

final inventoryLocalDataSourceProvider = Provider<InventoryLocalDataSource>((
  ref,
) {
  return InventoryLocalDataSource(ref.read(appDatabaseProvider));
});
