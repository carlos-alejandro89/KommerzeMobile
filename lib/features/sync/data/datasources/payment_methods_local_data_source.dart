import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/payment_method.dart';
import 'package:sqflite/sqflite.dart';

class PaymentMethodsLocalDataSource {
  final AppDatabase database;
  const PaymentMethodsLocalDataSource(this.database);

  Future<void> replaceAll(List<PaymentMethod> items, DateTime syncedAt) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      await transaction.delete('metodos_pago');
      final batch = transaction.batch();
      for (final item in items) {
        batch.insert('metodos_pago', {
          'guid': item.guid,
          'api_id': item.id,
          'clave': item.key,
          'descripcion': item.description,
          'is_active': item.isActive ? 1 : 0,
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
          await db.rawQuery('SELECT COUNT(*) FROM metodos_pago'),
        ) ??
        0;
  }

  Future<DateTime?> lastSynchronization() async {
    final db = await database.instance;
    final rows = await db.rawQuery(
      'SELECT MAX(synced_at) AS synced_at FROM metodos_pago',
    );
    final value = rows.isEmpty ? null : rows.first['synced_at']?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }
}

final paymentMethodsLocalDataSourceProvider =
    Provider<PaymentMethodsLocalDataSource>(
      (ref) => PaymentMethodsLocalDataSource(ref.read(appDatabaseProvider)),
    );
