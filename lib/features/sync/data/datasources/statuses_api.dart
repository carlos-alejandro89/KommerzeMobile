import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/sync/data/models/status_catalog_dto.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/status_catalog.dart';

class StatusesApi {
  final Dio dio;
  const StatusesApi(this.dio);

  Future<List<StatusCatalog>> getAll() async {
    try {
      final response = await dio.get<dynamic>(ApiConstants.statusesPath);
      final body = response.data;
      if (body is! Map) {
        throw const StatusesApiException(
          'El servicio devolvió una respuesta inválida.',
        );
      }
      final map = Map<String, dynamic>.from(body);
      if (map['success'] != true) {
        throw StatusesApiException(
          map['mensaje']?.toString() ??
              'No fue posible descargar el catálogo de estatus.',
        );
      }
      final data = map['data'];
      if (data is! List) {
        throw const StatusesApiException(
          'El catálogo de estatus no contiene datos válidos.',
        );
      }
      return data
          .whereType<Map>()
          .map(
            (row) => StatusCatalogDto.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((item) => item.guid.isNotEmpty && item.name.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['mensaje'] ?? body['message'])?.toString()
          : null;
      throw StatusesApiException(
        message ?? 'No fue posible conectar con el catálogo de estatus.',
      );
    }
  }
}

class StatusesApiException implements Exception {
  final String message;
  const StatusesApiException(this.message);
  @override
  String toString() => message;
}

final statusesApiProvider = Provider<StatusesApi>(
  (ref) => StatusesApi(ref.read(dioProvider)),
);
