import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/features/clients/data/models/client_request_dto.dart';
import 'package:kommerze_mobile/features/clients/data/models/client_response_dto.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:uuid/uuid.dart';

class ClientsApi {
  final Dio dio;
  const ClientsApi(this.dio);

  Future<List<Client>> listAll() async {
    try {
      final response = await dio.get<dynamic>(ApiConstants.clientsListPath);
      final body = response.data;
      if (body is! Map) {
        throw const ClientsApiException(
          'El servicio devolvió una respuesta inválida.',
        );
      }
      final map = Map<String, dynamic>.from(body);
      if (map['success'] != true) {
        throw ClientsApiException(
          _message(map) ?? 'No fue posible descargar los clientes.',
        );
      }
      final data = map['data'];
      if (data is! List) {
        throw const ClientsApiException(
          'El catálogo de clientes no contiene datos válidos.',
        );
      }
      return data
          .whereType<Map>()
          .map(
            (row) => ClientResponseDto.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((client) => client.guid.isNotEmpty && client.name.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (error) {
      throw ClientsApiException(
        _errorMessage(error, 'No fue posible descargar los clientes.'),
      );
    }
  }

  Future<String> create(ClientDraft draft) async {
    final localGuid = const Uuid().v4();
    final request = ClientRequestDto(draft: draft);
    try {
      final response = await dio.post<dynamic>(
        '/clientes/crear',
        data: request.toJson(),
      );
      _validate(response.data, fallback: 'No fue posible crear el cliente.');
      return _responseGuid(response.data) ?? localGuid;
    } on DioException catch (error) {
      throw ClientsApiException(
        _errorMessage(error, 'No fue posible crear el cliente.'),
      );
    }
  }

  Future<void> update(String guid, ClientDraft draft) async {
    final request = ClientRequestDto(draft: draft);
    try {
      final response = await dio.patch<dynamic>(
        '/clientes/editar/$guid',
        data: request.toJson(),
      );
      _validate(
        response.data,
        fallback: 'No fue posible actualizar el cliente.',
      );
    } on DioException catch (error) {
      throw ClientsApiException(
        _errorMessage(error, 'No fue posible actualizar el cliente.'),
      );
    }
  }

  Future<void> delete(String guid) async {
    try {
      final response = await dio.delete<dynamic>('/clientes/eliminar/$guid');
      _validate(response.data, fallback: 'No fue posible eliminar el cliente.');
    } on DioException catch (error) {
      throw ClientsApiException(
        _errorMessage(error, 'No fue posible eliminar el cliente.'),
      );
    }
  }

  void _validate(Object? body, {required String fallback}) {
    if (body is! Map) return;
    final map = Map<String, dynamic>.from(body);
    if (map.containsKey('success') && map['success'] != true) {
      throw ClientsApiException(_message(map) ?? fallback);
    }
  }

  String? _responseGuid(Object? body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    final data = map['data'];
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);
      final direct = dataMap['guid'] ?? dataMap['clienteGuid'];
      if (direct != null && direct.toString().isNotEmpty) {
        return direct.toString();
      }
      final client = dataMap['cliente'];
      if (client is Map) return client['guid']?.toString();
    }
    return map['guid']?.toString();
  }

  String _errorMessage(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map) {
      return _message(Map<String, dynamic>.from(data)) ?? fallback;
    }
    return fallback;
  }

  String? _message(Map<String, dynamic> body) =>
      (body['mensaje'] ?? body['message'])?.toString();
}

class ClientsApiException implements Exception {
  final String message;
  const ClientsApiException(this.message);
  @override
  String toString() => message;
}

final clientsApiProvider = Provider<ClientsApi>((ref) {
  return ClientsApi(ref.read(dioProvider));
});
