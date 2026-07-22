import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/status_catalog.dart';
import 'package:sqflite/sqflite.dart';

class StatusesLocalDataSource {
  final AppDatabase database;
  const StatusesLocalDataSource(this.database);

  Future<void> replaceAll(List<StatusCatalog> items, DateTime syncedAt) async {
    final db = await database.instance;
    final receivableColumns = await db.rawQuery(
      'PRAGMA table_info(cuentas_por_cobrar)',
    );
    final hasLegacyStatus = receivableColumns.any(
      (column) => column['name'] == 'estatus',
    );
    await db.transaction((transaction) async {
      final batch = transaction.batch();
      for (final item in items) {
        batch.rawInsert(
          '''
          INSERT INTO estatus (
            guid, api_id, nombre, created_at, updated_at, deleted_at, synced_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(guid) DO UPDATE SET
            api_id = excluded.api_id,
            nombre = excluded.nombre,
            created_at = excluded.created_at,
            updated_at = excluded.updated_at,
            deleted_at = excluded.deleted_at,
            synced_at = excluded.synced_at
          ''',
          [
            item.guid,
            item.id,
            item.name,
            item.createdAt?.toIso8601String(),
            item.updatedAt?.toIso8601String(),
            item.deletedAt?.toIso8601String(),
            syncedAt.toUtc().toIso8601String(),
          ],
        );
      }
      await batch.commit(noResult: true);
      if (hasLegacyStatus) {
        await transaction.rawUpdate('''
          UPDATE cuentas_por_cobrar
          SET estatus_guid = (
            SELECT e.guid
            FROM estatus e
            WHERE LOWER(e.nombre) = CASE LOWER(cuentas_por_cobrar.estatus)
              WHEN 'cancelada' THEN 'cancelado'
              ELSE LOWER(cuentas_por_cobrar.estatus)
            END
            LIMIT 1
          )
          WHERE estatus_guid IS NULL
        ''');
      }
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
