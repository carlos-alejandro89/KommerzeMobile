import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/user_catalog.dart';
import 'package:sqflite/sqflite.dart';

class UsersLocalDataSource {
  final AppDatabase database;
  const UsersLocalDataSource(this.database);

  Future<void> replaceAll(List<UserCatalog> users, DateTime syncedAt) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      await transaction.delete('usuarios');
      final batch = transaction.batch();
      for (final user in users) {
        batch.insert('usuarios', {
          'guid': user.guid,
          'api_id': user.id,
          'perfil_id': user.profileId,
          'nombre': user.name,
          'telefono': user.phone,
          'correo_electronico': user.email,
          'correo_confirmado': user.emailConfirmed ? 1 : 0,
          'img_perfil': user.profileImage,
          'created_at': user.createdAt?.toIso8601String(),
          'updated_at': user.updatedAt?.toIso8601String(),
          'deleted_at': user.deletedAt?.toIso8601String(),
          'synced_at': syncedAt.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> count() async {
    final db = await database.instance;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM usuarios'),
        ) ??
        0;
  }

  Future<DateTime?> lastSynchronization() async {
    final db = await database.instance;
    final rows = await db.rawQuery(
      'SELECT MAX(synced_at) AS synced_at FROM usuarios',
    );
    final value = rows.isEmpty ? null : rows.first['synced_at']?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }
}

final usersLocalDataSourceProvider = Provider<UsersLocalDataSource>(
  (ref) => UsersLocalDataSource(ref.read(appDatabaseProvider)),
);
