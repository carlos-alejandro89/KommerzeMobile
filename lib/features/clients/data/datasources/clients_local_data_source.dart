import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';

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
