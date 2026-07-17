import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/profile_catalog.dart';
import 'package:sqflite/sqflite.dart';

class ProfilesLocalDataSource {
  final AppDatabase database;
  const ProfilesLocalDataSource(this.database);

  Future<void> replaceAll(List<ProfileCatalog> items, DateTime syncedAt) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      await transaction.delete('perfiles');
      final batch = transaction.batch();
      for (final item in items) {
        batch.insert('perfiles', {
          'guid': item.guid,
          'api_id': item.id,
          'nombre_perfil': item.name,
          'created_at': item.createdAt.toIso8601String(),
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
          await db.rawQuery('SELECT COUNT(*) FROM perfiles'),
        ) ??
        0;
  }

  Future<DateTime?> lastSynchronization() async {
    final db = await database.instance;
    final rows = await db.rawQuery(
      'SELECT MAX(synced_at) AS synced_at FROM perfiles',
    );
    final value = rows.isEmpty ? null : rows.first['synced_at']?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }
}

final profilesLocalDataSourceProvider = Provider<ProfilesLocalDataSource>(
  (ref) => ProfilesLocalDataSource(ref.read(appDatabaseProvider)),
);
