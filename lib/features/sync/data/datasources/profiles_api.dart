import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/sync/data/models/profile_catalog_dto.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/profile_catalog.dart';

class ProfilesApi {
  final Dio dio;
  const ProfilesApi(this.dio);

  Future<List<ProfileCatalog>> getAll() async {
    try {
      final response = await dio.get<dynamic>(ApiConstants.profilesPath);
      final body = response.data;
      if (body is! Map) {
        throw const ProfilesApiException(
          'El servicio devolvió una respuesta inválida.',
        );
      }
      final map = Map<String, dynamic>.from(body);
      if (map['success'] != true) {
        throw ProfilesApiException(
          map['mensaje']?.toString() ??
              'No fue posible descargar los perfiles.',
        );
      }
      final data = map['data'];
      if (data is! List) {
        throw const ProfilesApiException(
          'El catálogo de perfiles no contiene datos válidos.',
        );
      }
      return data
          .whereType<Map>()
          .map(
            (row) => ProfileCatalogDto.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((item) => item.guid.isNotEmpty && item.name.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['mensaje'] ?? body['message'])?.toString()
          : null;
      throw ProfilesApiException(
        message ?? 'No fue posible conectar con el catálogo de perfiles.',
      );
    }
  }
}

class ProfilesApiException implements Exception {
  final String message;
  const ProfilesApiException(this.message);
  @override
  String toString() => message;
}

final profilesApiProvider = Provider<ProfilesApi>(
  (ref) => ProfilesApi(ref.read(dioProvider)),
);
