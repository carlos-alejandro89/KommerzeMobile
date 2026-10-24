import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/features/branch_operation/domain/entities/branch_operation.dart';

class BranchOperationApi {
  static const terminatedStatusGuid = '2f3b4c7e-91d2-45af-b6f1-9c3d8e2a7b55';

  final Dio dio;

  const BranchOperationApi(this.dio);

  Future<void> startBranchOperation({
    required BranchOperation operation,
    required String branchGuid,
  }) {
    return _post(
      ApiConstants.branchOperationStartPath,
      data: {
        'usuarioAperturaGuid': operation.openingUserGuid,
        'sucursalGuid': branchGuid,
        'fechaInicio': operation.startDate.toUtc().toIso8601String(),
        'valorInicialInventario': operation.initialInventoryValue,
        'guid': operation.guid,
      },
      fallback: 'No fue posible reportar la apertura de la sucursal.',
      acceptConflict: true,
    );
  }

  Future<void> startCashierShift(BranchOperation operation) {
    return _post(
      ApiConstants.cashierShiftStartPath,
      data: {
        'operacionSucursalGuid': operation.guid,
        'responsableCajaGuid': operation.openingUserGuid,
        'caja': 'Caja 1',
        'fechaInicio': operation.startDate.toUtc().toIso8601String(),
        'fondoCajaApertura': operation.initialCashAmount,
        'guidOperacionCajero': operation.guid,
      },
      fallback: 'No fue posible reportar la apertura de caja.',
      acceptConflict: true,
    );
  }

  Future<void> finishCashierShift(BranchOperation operation) {
    return _put(
      ApiConstants.cashierShiftFinishPath,
      data: {
        'operacionCajaGuid': operation.guid,
        'estatusGuid': terminatedStatusGuid,
        'fechaFin': operation.endDate!.toUtc().toIso8601String(),
        'fondoCajaCierre': operation.initialCashAmount + operation.cashIncome,
        'retirosEfectivo': 0,
        'ingresoEfectivo': operation.cashIncome,
        'ingresoTarjetas': operation.cardIncome,
        'ingresoCheques': operation.checkIncome,
        'ingresoTransferencia': operation.transferIncome,
        'ingresoOtros': operation.otherIncome,
        'bloqueada': false,
      },
      fallback: 'No fue posible reportar el cierre de caja.',
    );
  }

  Future<void> finishBranchOperation({
    required BranchOperation operation,
    required String closingUserGuid,
  }) {
    return _put(
      ApiConstants.branchOperationFinishPath,
      data: {
        'operacionGuid': operation.guid,
        'usuarioCierreGuid': closingUserGuid,
        'estatusGuid': terminatedStatusGuid,
        'fechaInicio': operation.startDate.toUtc().toIso8601String(),
        'fechaFin': operation.endDate!.toUtc().toIso8601String(),
        'valorInicialInventario': operation.initialInventoryValue,
        'valorCompras': operation.purchasesValue,
        'valorVentas': operation.salesValue,
        'descuentosAplicados': operation.appliedDiscounts,
        'ajusteInventario': operation.inventoryAdjustment,
        'valorFinalInventario': operation.finalInventoryValue,
        'ingresoEfectivo': operation.cashIncome,
        'ingresoTarjetas': operation.cardIncome,
        'ingresoCheques': operation.checkIncome,
        'ingresoTransferencia': operation.transferIncome,
        'ingresoOtros': operation.otherIncome,
        'creditos': operation.credits,
        'valesSalida': operation.outgoingVouchers,
        'valesEntrantes': operation.incomingVouchers,
        'cfdiEfectivo': operation.cashCfdi,
        'cfdiTarjetas': operation.cardCfdi,
        'cfdiCheques': operation.checkCfdi,
        'cfdiTransferencia': operation.transferCfdi,
        'cfdiOtros': operation.otherCfdi,
        'bajasMercancia': operation.merchandiseLosses,
      },
      fallback: 'No fue posible reportar el cierre de la sucursal.',
    );
  }

  Future<void> _post(
    String path, {
    required Map<String, Object?> data,
    required String fallback,
    bool acceptConflict = false,
  }) async {
    try {
      final response = await dio.post<dynamic>(path, data: data);
      _validate(response.data, fallback);
    } on DioException catch (error) {
      if (acceptConflict && error.response?.statusCode == 409) return;
      throw BranchOperationApiException(
        _message(error.response?.data, fallback),
      );
    }
  }

  Future<void> _put(
    String path, {
    required Map<String, Object?> data,
    required String fallback,
  }) async {
    try {
      final response = await dio.put<dynamic>(path, data: data);
      _validate(response.data, fallback);
    } on DioException catch (error) {
      throw BranchOperationApiException(
        _message(error.response?.data, fallback),
      );
    }
  }

  void _validate(Object? body, String fallback) {
    if (body is Map && body['success'] == false) {
      throw BranchOperationApiException(_message(body, fallback));
    }
  }

  String _message(Object? body, String fallback) {
    if (body is Map) {
      return (body['mensaje'] ?? body['message'])?.toString() ?? fallback;
    }
    return fallback;
  }
}

class BranchOperationApiException implements Exception {
  final String message;

  const BranchOperationApiException(this.message);

  @override
  String toString() => message;
}

final branchOperationApiProvider = Provider<BranchOperationApi>((ref) {
  return BranchOperationApi(ref.watch(dioProvider));
});
