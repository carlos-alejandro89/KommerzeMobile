import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/storage/app_database.dart';
import 'package:kommerze_mobile/features/branch_operation/domain/entities/branch_operation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class BranchOperationLocalDataSource {
  static const activeStatus = 1;
  static const closedStatus = 2;
  final AppDatabase database;

  const BranchOperationLocalDataSource(this.database);

  Future<BranchOperation?> getActive() async {
    final db = await database.instance;
    final rows = await db.query(
      'operaciones_sucursal',
      where: 'estatus_id = ? AND fecha_fin IS NULL AND deleted_at IS NULL',
      whereArgs: const [activeStatus],
      orderBy: 'fecha_inicio DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : BranchOperation.fromMap(rows.first);
  }

  Future<double> getInventoryValue() async {
    final db = await database.instance;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(existencia * precio_compra), 0) AS total '
      'FROM inventario',
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> getBranchId() async {
    final db = await database.instance;
    final rows = await db.query('sucursales', columns: ['id'], limit: 1);
    if (rows.isEmpty) {
      throw const BranchOperationException(
        'No existe una sucursal activa para iniciar operaciones.',
      );
    }
    return (rows.first['id'] as num).toInt();
  }

  Future<BranchOperation> open({
    required int userId,
    required double initialCashAmount,
    required String? notes,
  }) async {
    final db = await database.instance;
    final existing = await getActive();
    if (existing != null) return existing;
    final now = DateTime.now().toUtc().toIso8601String();
    final guid = const Uuid().v4();
    await db.insert('operaciones_sucursal', {
      'guid': guid,
      'usuario_apertura_id': userId,
      'sucursal_id': await getBranchId(),
      'estatus_id': activeStatus,
      'fecha_inicio': now,
      'valor_inicial_inventario': await getInventoryValue(),
      'monto_inicial_caja': initialCashAmount,
      'observaciones': notes?.trim(),
      'created_at': now,
      'updated_at': now,
    });
    final rows = await db.query(
      'operaciones_sucursal',
      where: 'guid = ?',
      whereArgs: [guid],
      limit: 1,
    );
    return BranchOperation.fromMap(rows.first);
  }

  Future<void> close({
    required String operationGuid,
    required int userId,
  }) async {
    final db = await database.instance;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'operaciones_sucursal',
      {
        'usuario_cierre_id': userId,
        'estatus_id': closedStatus,
        'fecha_fin': now,
        'valor_final_inventario': await getInventoryValue(),
        'updated_at': now,
      },
      where: 'guid = ? AND fecha_fin IS NULL',
      whereArgs: [operationGuid],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }
}

class BranchOperationException implements Exception {
  final String message;
  const BranchOperationException(this.message);
  @override
  String toString() => message;
}

final branchOperationLocalDataSourceProvider =
    Provider<BranchOperationLocalDataSource>((ref) {
      return BranchOperationLocalDataSource(ref.read(appDatabaseProvider));
    });
