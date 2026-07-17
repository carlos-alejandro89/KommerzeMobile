import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/sync/data/models/payment_form_dto.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/payment_form.dart';

class PaymentFormsApi {
  final Dio dio;
  const PaymentFormsApi(this.dio);

  Future<List<PaymentForm>> getAll() async {
    try {
      final response = await dio.get<dynamic>(ApiConstants.paymentFormsPath);
      final body = response.data;
      if (body is! Map) {
        throw const PaymentFormsApiException(
          'El servicio devolvió una respuesta inválida.',
        );
      }
      final map = Map<String, dynamic>.from(body);
      if (map['success'] != true) {
        throw PaymentFormsApiException(
          map['mensaje']?.toString() ??
              'No fue posible descargar las formas de pago.',
        );
      }
      final data = map['data'];
      if (data is! List) {
        throw const PaymentFormsApiException(
          'El catálogo de formas de pago no contiene datos válidos.',
        );
      }
      return data
          .whereType<Map>()
          .map((row) => PaymentFormDto.fromJson(Map<String, dynamic>.from(row)))
          .where((item) => item.guid.isNotEmpty && item.key.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['mensaje'] ?? body['message'])?.toString()
          : null;
      throw PaymentFormsApiException(
        message ?? 'No fue posible conectar con el catálogo de formas de pago.',
      );
    }
  }
}

class PaymentFormsApiException implements Exception {
  final String message;
  const PaymentFormsApiException(this.message);
  @override
  String toString() => message;
}

final paymentFormsApiProvider = Provider<PaymentFormsApi>(
  (ref) => PaymentFormsApi(ref.read(dioProvider)),
);
