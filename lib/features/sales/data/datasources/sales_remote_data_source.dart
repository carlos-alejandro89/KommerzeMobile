import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/sales/data/models/sale_order_request_dto.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_order.dart';

class SalesRemoteDataSource {
  final Dio dio;
  const SalesRemoteDataSource(this.dio);

  Future<void> register(SaleOrder order) async {
    try {
      final response = await dio.post<dynamic>(
        ApiConstants.salesRegisterPath,
        data: SaleOrderRequestDto(order).toJson(),
      );
      final body = response.data;
      if (body is! Map) {
        throw const SalesSyncException(
          'El servicio de ventas devolvió una respuesta inválida.',
        );
      }
      final map = Map<String, dynamic>.from(body);
      final httpCode = _integer(map['httpCode']);
      if (map['success'] != true || (httpCode != 0 && httpCode ~/ 100 != 2)) {
        throw SalesSyncException(
          _message(map) ?? 'No fue posible sincronizar la venta.',
        );
      }
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map) {
        final message = _message(Map<String, dynamic>.from(data));
        if (message != null && message.isNotEmpty) {
          throw SalesSyncException(message);
        }
      }
      throw const SalesSyncException(
        'No fue posible conectar con Kommerze Cloud. La venta quedó pendiente.',
      );
    }
  }

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static String? _message(Map<String, dynamic> body) =>
      (body['mensaje'] ?? body['message'])?.toString();
}

class SalesSyncException implements Exception {
  final String message;
  const SalesSyncException(this.message);

  @override
  String toString() => message;
}

final salesRemoteDataSourceProvider = Provider<SalesRemoteDataSource>(
  (ref) => SalesRemoteDataSource(ref.read(dioProvider)),
);
