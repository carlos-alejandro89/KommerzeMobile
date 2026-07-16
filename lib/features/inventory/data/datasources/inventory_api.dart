import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/inventory/data/models/inventory_dto.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';

class InventoryApi {
  final Dio dio;

  const InventoryApi(this.dio);

  Future<List<InventoryItem>> getPrices(String branchGuid) async {
    return _request('/lista-precios/get-precios/$branchGuid', backup: false);
  }

  Future<List<InventoryItem>> recoverInventory(String branchGuid) async {
    return _request(
      '/sucursales/inventario/recuperar/$branchGuid',
      backup: true,
    );
  }

  Future<List<InventoryItem>> _request(
    String path, {
    required bool backup,
  }) async {
    try {
      final response = await dio.get<dynamic>(path);
      final rows = _extractList(response.data, backup ? 'backup' : 'precios');
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .map(backup ? InventoryDto.fromBackup : InventoryDto.fromPrice)
          .where((item) => item.levelGuid.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['mensaje'] ?? body['message'])?.toString()
          : null;
      throw InventoryApiException(
        message ?? 'No fue posible conectar con el servicio de inventario.',
      );
    }
  }

  List<dynamic> _extractList(Object? body, String preferredKey) {
    if (body is List) return body;
    if (body is! Map) return const [];
    final map = Map<String, dynamic>.from(body);
    final preferred = map[preferredKey];
    if (preferred is List) return preferred;
    final data = map['data'];
    if (data is List) return data;
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);
      final nested = dataMap[preferredKey];
      if (nested is List) return nested;
      for (final value in dataMap.values) {
        if (value is List) return value;
      }
    }
    return const [];
  }
}

class InventoryApiException implements Exception {
  final String message;
  const InventoryApiException(this.message);
  @override
  String toString() => message;
}

final inventoryApiProvider = Provider<InventoryApi>((ref) {
  return InventoryApi(ref.read(dioProvider));
});
