import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/sync/data/models/order_type_catalog_dto.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/order_type_catalog.dart';

class OrderTypesApi {
  final Dio dio;
  const OrderTypesApi(this.dio);

  Future<List<OrderTypeCatalog>> getAll() async {
    try {
      final response = await dio.get<dynamic>(ApiConstants.orderTypesPath);
      final body = response.data;
      if (body is! Map) {
        throw const OrderTypesApiException(
          'El servicio devolvió una respuesta inválida.',
        );
      }
      final map = Map<String, dynamic>.from(body);
      if (map['success'] != true) {
        throw OrderTypesApiException(
          map['mensaje']?.toString() ??
              'No fue posible descargar los tipos de pedido.',
        );
      }
      final data = map['data'];
      if (data is! List) {
        throw const OrderTypesApiException(
          'El catálogo de tipos de pedido no contiene datos válidos.',
        );
      }
      return data
          .whereType<Map>()
          .map(
            (row) =>
                OrderTypeCatalogDto.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((item) => item.guid.isNotEmpty && item.name.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['mensaje'] ?? body['message'])?.toString()
          : null;
      throw OrderTypesApiException(
        message ??
            'No fue posible conectar con el catálogo de tipos de pedido.',
      );
    }
  }
}

class OrderTypesApiException implements Exception {
  final String message;
  const OrderTypesApiException(this.message);
  @override
  String toString() => message;
}

final orderTypesApiProvider = Provider<OrderTypesApi>(
  (ref) => OrderTypesApi(ref.read(dioProvider)),
);
