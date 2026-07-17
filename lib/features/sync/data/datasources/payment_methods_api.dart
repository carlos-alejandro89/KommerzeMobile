import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/sync/data/models/payment_method_dto.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/payment_method.dart';

class PaymentMethodsApi {
  final Dio dio;
  const PaymentMethodsApi(this.dio);

  Future<List<PaymentMethod>> getAll() async {
    try {
      final response = await dio.get<dynamic>(ApiConstants.paymentMethodsPath);
      final body = response.data;
      if (body is! Map) {
        throw const PaymentMethodsApiException(
          'El servicio devolvió una respuesta inválida.',
        );
      }
      final map = Map<String, dynamic>.from(body);
      if (map['success'] != true) {
        throw PaymentMethodsApiException(
          map['mensaje']?.toString() ??
              'No fue posible descargar los métodos de pago.',
        );
      }
      final data = map['data'];
      if (data is! List) {
        throw const PaymentMethodsApiException(
          'El catálogo de métodos de pago no contiene datos válidos.',
        );
      }
      return data
          .whereType<Map>()
          .map(
            (row) => PaymentMethodDto.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((item) => item.guid.isNotEmpty && item.key.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['mensaje'] ?? body['message'])?.toString()
          : null;
      throw PaymentMethodsApiException(
        message ??
            'No fue posible conectar con el catálogo de métodos de pago.',
      );
    }
  }
}

class PaymentMethodsApiException implements Exception {
  final String message;
  const PaymentMethodsApiException(this.message);
  @override
  String toString() => message;
}

final paymentMethodsApiProvider = Provider<PaymentMethodsApi>(
  (ref) => PaymentMethodsApi(ref.read(dioProvider)),
);
