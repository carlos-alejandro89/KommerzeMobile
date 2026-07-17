import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/sync/data/models/user_catalog_dto.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/user_catalog.dart';

class UsersApi {
  final Dio dio;
  const UsersApi(this.dio);

  Future<List<UserCatalog>> getAll() async {
    try {
      final response = await dio.get<dynamic>(ApiConstants.usersPath);
      final body = response.data;
      if (body is! Map) {
        throw const UsersApiException(
          'El servicio devolvió una respuesta inválida.',
        );
      }
      final map = Map<String, dynamic>.from(body);
      if (map['success'] != true) {
        throw UsersApiException(
          map['mensaje']?.toString() ??
              'No fue posible descargar los usuarios.',
        );
      }
      final data = map['data'];
      if (data is! List) {
        throw const UsersApiException(
          'El catálogo de usuarios no contiene datos válidos.',
        );
      }
      return data
          .whereType<Map>()
          .map((row) => UserCatalogDto.fromJson(Map<String, dynamic>.from(row)))
          .where((user) => user.guid.isNotEmpty && user.name.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['mensaje'] ?? body['message'])?.toString()
          : null;
      throw UsersApiException(
        message ?? 'No fue posible conectar con el catálogo de usuarios.',
      );
    }
  }
}

class UsersApiException implements Exception {
  final String message;
  const UsersApiException(this.message);
  @override
  String toString() => message;
}

final usersApiProvider = Provider<UsersApi>(
  (ref) => UsersApi(ref.read(dioProvider)),
);
