import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/loans/data/models/loan_sync_batch.dart';

class LoansRemoteDataSource {
  final Dio dio;

  const LoansRemoteDataSource(this.dio);

  Future<LoanSyncResult> synchronize(LoanSyncBatch batch) async {
    try {
      final response = await dio.post<dynamic>(
        ApiConstants.loansSyncPath,
        data: batch.toJson(),
      );
      final data = _successfulData(response.data);
      return LoanSyncResult.fromJson(data);
    } on DioException catch (error) {
      throw LoansSyncException(
        _responseMessage(error.response?.data) ??
            'No fue posible sincronizar los préstamos.',
      );
    }
  }

  Future<LoanSyncBatch> recoverByBranch(String branchGuid) async {
    try {
      final response = await dio.get<dynamic>(
        ApiConstants.loansByBranchPath(branchGuid),
      );
      return LoanSyncBatch.fromJson(_successfulData(response.data));
    } on DioException catch (error) {
      throw LoansSyncException(
        _responseMessage(error.response?.data) ??
            'No fue posible recuperar los préstamos.',
      );
    }
  }

  static Map<String, dynamic> _successfulData(Object? body) {
    if (body is! Map) {
      throw const LoansSyncException(
        'El servicio devolvió una respuesta inválida.',
      );
    }
    final map = Map<String, dynamic>.from(body);
    final code = _integer(map['httpCode'] ?? map['HttpCode']);
    final success = map['success'] == true || map['Success'] == true;
    if (!success || (code != 0 && code ~/ 100 != 2)) {
      throw LoansSyncException(
        _responseMessage(map) ?? 'No fue posible procesar los préstamos.',
      );
    }
    final data = map['data'] ?? map['Data'];
    if (data is! Map) {
      throw const LoansSyncException(
        'El servicio no devolvió información de préstamos.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  static String? _responseMessage(Object? body) {
    if (body is! Map) return null;
    return (body['mensaje'] ?? body['Mensaje'] ?? body['message'])?.toString();
  }

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

class LoansSyncException implements Exception {
  final String message;
  const LoansSyncException(this.message);
  @override
  String toString() => message;
}

final loansRemoteDataSourceProvider = Provider<LoansRemoteDataSource>((ref) {
  return LoansRemoteDataSource(ref.read(dioProvider));
});
