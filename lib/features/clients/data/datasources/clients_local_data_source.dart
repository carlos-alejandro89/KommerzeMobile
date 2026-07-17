import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:sqflite/sqflite.dart';

class ClientsLocalDataSource {
  final AppDatabase database;
  const ClientsLocalDataSource(this.database);

  Future<List<Client>> getAll() async {
    final db = await database.instance;
    final rows = await db.query(
      'clientes',
      where: 'deleted_at IS NULL',
      orderBy: 'nombre COLLATE NOCASE',
    );
    return rows.map(Client.fromMap).toList(growable: false);
  }

  Future<void> create(ClientDraft draft, {required String guid}) async {
    final db = await database.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('clientes', {
      'guid': guid,
      ..._draftMap(draft),
      'activo': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> update(String guid, ClientDraft draft) async {
    final db = await database.instance;
    await db.update(
      'clientes',
      {
        ..._draftMap(draft),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'guid = ? AND deleted_at IS NULL',
      whereArgs: [guid],
    );
  }

  Future<void> setActive(String guid, {required bool active}) async {
    final db = await database.instance;
    await db.update(
      'clientes',
      {
        'activo': active ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'guid = ? AND deleted_at IS NULL',
      whereArgs: [guid],
    );
  }

  Future<void> delete(String guid) async {
    final db = await database.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'clientes',
      {'deleted_at': now, 'updated_at': now, 'activo': 0},
      where: 'guid = ?',
      whereArgs: [guid],
    );
  }

  Future<void> upsertRemote(
    List<Client> clients, {
    required DateTime syncedAt,
  }) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      final batch = transaction.batch();
      for (final client in clients) {
        batch.insert('clientes', {
          'guid': client.guid,
          'nombre': client.name,
          'rfc': client.rfc,
          'correo': client.email,
          'telefono': client.phone,
          'monto_credito': client.creditAmount,
          'dias_credito': client.creditDays,
          'activo': client.isActive ? 1 : 0,
          'created_at': client.createdAt.toUtc().toIso8601String(),
          'updated_at': client.updatedAt.toUtc().toIso8601String(),
          'deleted_at': null,
          'synced_at': syncedAt.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> synchronizedCount() async {
    final db = await database.instance;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM clientes WHERE synced_at IS NOT NULL',
          ),
        ) ??
        0;
  }

  Future<DateTime?> lastSynchronization() async {
    final db = await database.instance;
    final rows = await db.rawQuery(
      'SELECT MAX(synced_at) AS synced_at FROM clientes',
    );
    final value = rows.isEmpty ? null : rows.first['synced_at']?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  Map<String, Object?> _draftMap(ClientDraft draft) => {
    'nombre': draft.name.trim(),
    'rfc': draft.rfc.trim().toUpperCase(),
    'correo': draft.email.trim().toLowerCase(),
    'telefono': draft.phone.trim(),
    'monto_credito': draft.creditAmount,
    'dias_credito': draft.creditDays,
  };
}

final clientsLocalDataSourceProvider = Provider<ClientsLocalDataSource>((ref) {
  return ClientsLocalDataSource(ref.read(appDatabaseProvider));
});
