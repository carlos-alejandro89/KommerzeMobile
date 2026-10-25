import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/inventory/data/models/inventory_dto.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';

class InventoryApi {
  final Dio dio;

  const InventoryApi(this.dio);

  Future<List<InventoryItem>> getPrices(String branchGuid) async {
    return _request('lista-precios/get-precios/$branchGuid', backup: false);
  }

  Future<List<InventoryItem>> recoverInventory(String branchGuid) async {
    return _request(
      'sucursales/inventario/recuperar/$branchGuid',
      backup: true,
    );
  }

  Future<void> backupInventory(
    String branchGuid,
    List<InventoryItem> items,
  ) async {
    try {
      final response = await dio.post<dynamic>(
        'sucursales/inventario/backup/$branchGuid',
        data: items.map(InventoryDto.toBackupPayload).toList(growable: false),
      );
      final body = response.data;
      if (body is Map && body['success'] == false) {
        throw InventoryApiException(
          (body['mensaje'] ??
                  body['message'] ??
                  'No fue posible respaldar el inventario.')
              .toString(),
        );
      }
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['mensaje'] ?? body['message'])?.toString()
          : null;
      throw InventoryApiException(
        message ?? 'No fue posible respaldar el inventario.',
      );
    }
  }

  Future<Map<String, double>> validateAvailability(
    String branchGuid,
    Map<String, double> quantities,
  ) async {
    try {
      final response = await dio.post<dynamic>(
        ApiConstants.inventoryValidationPath(branchGuid),
        data: [
          for (final entry in quantities.entries)
            {'nivelGuid': entry.key, 'cantidad': entry.value},
        ],
      );
      final body = response.data;
      if (body is! Map || body['success'] != true || body['data'] is! List) {
        throw InventoryApiException(
          body is Map
              ? (body['mensaje'] ?? body['message'])?.toString() ??
                    'No fue posible validar el inventario Cloud.'
              : 'El servidor devolvió una respuesta inválida.',
        );
      }
      return {
        for (final row in (body['data'] as List).whereType<Map>())
          if ((row['nivelGuid'] ?? row['NivelGuid'])?.toString().isNotEmpty ==
              true)
            (row['nivelGuid'] ?? row['NivelGuid']).toString(): _decimal(
              row['existencia'] ?? row['Existencia'],
            ),
      };
    } on InventoryApiException {
      rethrow;
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map) {
        final message = body['mensaje'] ?? body['message'];
        if (message != null && message.toString().isNotEmpty) {
          throw InventoryApiException(message.toString());
        }
      }
      throw const InventoryApiException('No hay conexión con el servidor.');
    }
  }

  Future<bool> usesCloudInventory(String branchGuid) async {
    try {
      final response = await dio.get<dynamic>(
        'sucursales/inventario/configuracion/$branchGuid',
      );
      final body = response.data;
      final data = body is Map && body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : const <String, dynamic>{};
      return data['inventarioCloud'] == true || data['modo'] == 'cloud';
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['mensaje'] ?? body['message'])?.toString()
          : null;
      throw InventoryApiException(
        message ?? 'No fue posible consultar el modo de inventario.',
      );
    }
  }

  Future<void> configureCloudInventory(
    String branchGuid, {
    required bool enabled,
  }) async {
    try {
      final response = await dio.put<dynamic>(
        'sucursales/inventario/configuracion/$branchGuid',
        data: {'inventarioCloud': enabled},
      );
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw InventoryApiException(
          body is Map
              ? (body['mensaje'] ?? body['message'])?.toString() ??
                    'No fue posible actualizar el modo de inventario.'
              : 'El servidor devolvió una respuesta inválida.',
        );
      }
    } on InventoryApiException {
      rethrow;
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['mensaje'] ?? body['message'])?.toString()
          : null;
      throw InventoryApiException(
        message ?? 'No fue posible actualizar el modo de inventario.',
      );
    }
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

  static double _decimal(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class InventoryApiException implements Exception {
  final String message;
  const InventoryApiException(this.message);
  @override
  String toString() => message;
}

final inventoryApiProvider = Provider<InventoryApi>((ref) {
  return InventoryApi(ref.watch(dioProvider));
});
