import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/collections/data/models/collection_sync_batch.dart';

class CollectionsRemoteDataSource {
  final Dio dio;

  const CollectionsRemoteDataSource(this.dio);

  Future<CollectionSyncResult> synchronize(CollectionSyncBatch batch) async {
    try {
      final response = await dio.post<dynamic>(
        ApiConstants.collectionsSyncPath,
        data: batch.toJson(),
      );
      final body = response.data;
      if (body is! Map) {
        throw const CollectionsSyncException(
          'El servicio de cobranza devolvió una respuesta inválida.',
        );
      }
      final map = Map<String, dynamic>.from(body);
      final code = _integer(map['httpCode'] ?? map['HttpCode']);
      final success = map['success'] == true || map['Success'] == true;
      if (!success || (code != 0 && code ~/ 100 != 2)) {
        throw CollectionsSyncException(
          _message(map) ?? 'No fue posible sincronizar la cobranza.',
        );
      }
      final data = map['data'] ?? map['Data'];
      if (data is! Map) {
        throw const CollectionsSyncException(
          'El servicio no confirmó los registros sincronizados.',
        );
      }
      return CollectionSyncResult.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map) {
        final message = _message(Map<String, dynamic>.from(data));
        if (message != null && message.isNotEmpty) {
          throw CollectionsSyncException(message);
        }
      }
      throw const CollectionsSyncException(
        'No fue posible conectar con Kommerze Cloud. La cobranza quedó pendiente.',
      );
    }
  }

  Future<CollectionSyncBatch> recoverByBranch(String branchGuid) async {
    try {
      final response = await dio.get<dynamic>(
        ApiConstants.collectionsByBranchPath(branchGuid),
      );
      final data = _successfulData(response.data);
      return CollectionSyncBatch.fromJson(data);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map) {
        final message = _message(Map<String, dynamic>.from(data));
        if (message != null && message.isNotEmpty) {
          throw CollectionsSyncException(message);
        }
      }
      throw const CollectionsSyncException(
        'No fue posible recuperar la cobranza de Kommerze Cloud.',
      );
    }
  }

  static Map<String, dynamic> _successfulData(Object? body) {
    if (body is! Map) {
      throw const CollectionsSyncException(
        'El servicio de cobranza devolvió una respuesta inválida.',
      );
    }
    final map = Map<String, dynamic>.from(body);
    final code = _integer(map['httpCode'] ?? map['HttpCode']);
    final success = map['success'] == true || map['Success'] == true;
    if (!success || (code != 0 && code ~/ 100 != 2)) {
      throw CollectionsSyncException(
        _message(map) ?? 'No fue posible recuperar la cobranza.',
      );
    }
    final data = map['data'] ?? map['Data'];
    if (data is! Map) {
      throw const CollectionsSyncException(
        'El servicio no devolvió información de cobranza.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static String? _message(Map<String, dynamic> body) =>
      (body['mensaje'] ?? body['Mensaje'] ?? body['message'] ?? body['Message'])
          ?.toString();
}

class CollectionsSyncException implements Exception {
  final String message;

  const CollectionsSyncException(this.message);

  @override
  String toString() => message;
}

final collectionsRemoteDataSourceProvider =
    Provider<CollectionsRemoteDataSource>(
      (ref) => CollectionsRemoteDataSource(ref.read(dioProvider)),
    );
