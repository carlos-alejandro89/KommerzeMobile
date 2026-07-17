import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/status_catalog.dart';
import 'package:sqflite/sqflite.dart';

class StatusesLocalDataSource {
  final AppDatabase database;
  const StatusesLocalDataSource(this.database);

  Future<void> replaceAll(List<StatusCatalog> items, DateTime syncedAt) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      await transaction.delete('estatus');
      final batch = transaction.batch();
      for (final item in items) {
        batch.insert('estatus', {
          'guid': item.guid,
          'api_id': item.id,
          'nombre': item.name,
          'created_at': item.createdAt?.toIso8601String(),
          'updated_at': item.updatedAt?.toIso8601String(),
          'deleted_at': item.deletedAt?.toIso8601String(),
          'synced_at': syncedAt.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> count() async {
    final db = await database.instance;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM estatus'),
        ) ??
        0;
  }

  Future<DateTime?> lastSynchronization() async {
    final db = await database.instance;
    final rows = await db.rawQuery(
      'SELECT MAX(synced_at) AS synced_at FROM estatus',
    );
    final value = rows.isEmpty ? null : rows.first['synced_at']?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }
}

final statusesLocalDataSourceProvider = Provider<StatusesLocalDataSource>(
  (ref) => StatusesLocalDataSource(ref.read(appDatabaseProvider)),
);
