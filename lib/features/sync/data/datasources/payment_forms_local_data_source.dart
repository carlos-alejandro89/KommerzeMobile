import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/payment_form.dart';
import 'package:sqflite/sqflite.dart';

class PaymentFormsLocalDataSource {
  final AppDatabase database;
  const PaymentFormsLocalDataSource(this.database);

  Future<void> replaceAll(List<PaymentForm> items, DateTime syncedAt) async {
    final db = await database.instance;
    await db.transaction((transaction) async {
      await transaction.delete('formas_pago');
      final batch = transaction.batch();
      for (final item in items) {
        batch.insert('formas_pago', {
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
          await db.rawQuery('SELECT COUNT(*) FROM formas_pago'),
        ) ??
        0;
  }

  Future<DateTime?> lastSynchronization() async {
    final db = await database.instance;
    final rows = await db.rawQuery(
      'SELECT MAX(synced_at) AS synced_at FROM formas_pago',
    );
    final value = rows.isEmpty ? null : rows.first['synced_at']?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }
}

final paymentFormsLocalDataSourceProvider =
    Provider<PaymentFormsLocalDataSource>(
      (ref) => PaymentFormsLocalDataSource(ref.read(appDatabaseProvider)),
    );
