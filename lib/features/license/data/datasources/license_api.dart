import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/license/data/models/license_activation_request_dto.dart';
import 'package:kommerze_mobile/features/license/data/models/license_activation_response_dto.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_activation_result.dart';

class LicenseApi {
  final Dio dio;

  const LicenseApi(this.dio);

  Future<LicenseActivationResult> activate(
    LicenseActivationRequestDto request,
  ) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        ApiConstants.licenseActivationPath,
        data: request.toJson(),
      );
      final body = response.data ?? const <String, dynamic>{};
      return LicenseActivationResponseDto.fromJson(body);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map) {
        return LicenseActivationResult(
          success: false,
          message: _messageFrom(
            Map<String, dynamic>.from(data),
            fallback: 'No fue posible activar la licencia.',
          ),
        );
      }
      throw const LicenseApiException(
        'No fue posible conectar con el servicio de licencias.',
      );
    }
  }

  String _messageFrom(Map<String, dynamic> body, {required String fallback}) {
    return (body['mensaje'] ?? body['message'])?.toString() ?? fallback;
  }
}

class LicenseApiException implements Exception {
  final String message;

  const LicenseApiException(this.message);

  @override
  String toString() => message;
}

final licenseApiProvider = Provider<LicenseApi>((ref) {
  return LicenseApi(ref.read(dioProvider));
});
