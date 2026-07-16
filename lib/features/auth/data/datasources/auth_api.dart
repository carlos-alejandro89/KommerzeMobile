import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';

class AuthApi {
  final Dio dio;

  const AuthApi(this.dio);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        ApiConstants.loginPath,
        data: {'email': email.trim(), 'password': password},
      );
      final body = response.data;
      if (body == null) {
        throw const AuthApiException(
          'El servidor devolvió una respuesta vacía.',
        );
      }
      if (body['success'] != true) {
        throw AuthApiException(
          body['mensaje']?.toString() ?? 'No fue posible iniciar sesión.',
        );
      }
      return body;
    } on AuthApiException {
      rethrow;
    } on DioException catch (error) {
      final responseBody = error.response?.data;
      if (responseBody is Map) {
        final message = responseBody['mensaje'] ?? responseBody['message'];
        if (message != null && message.toString().isNotEmpty) {
          throw AuthApiException(message.toString());
        }
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        throw const AuthApiException(
          'No fue posible conectar con Kommerze. Verifica tu conexión.',
        );
      }
      throw const AuthApiException('No fue posible iniciar sesión.');
    }
  }
}

class AuthApiException implements Exception {
  final String message;

  const AuthApiException(this.message);

  @override
  String toString() => message;
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.read(dioProvider));
});
