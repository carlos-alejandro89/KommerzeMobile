import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kommerze_mobile/core/storage/secure_storage_provider.dart';
import 'package:kommerze_mobile/features/branch_operation/data/datasources/branch_operation_local_data_source.dart';
import 'package:kommerze_mobile/features/branch_operation/domain/entities/branch_operation_state.dart';

class BranchOperationRepository {
  final BranchOperationLocalDataSource local;
  final FlutterSecureStorage secureStorage;

  const BranchOperationRepository(this.local, this.secureStorage);

  Future<BranchOperationState> getState() async {
    return BranchOperationState(
      activeOperation: await local.getActive(),
      currentInventoryValue: await local.getInventoryValue(),
    );
  }

  Future<BranchOperationState> open({
    required double initialCashAmount,
    required String? notes,
  }) async {
    await local.open(
      userId: await _currentUserId(),
      initialCashAmount: initialCashAmount,
      notes: notes,
    );
    return getState();
  }

  Future<BranchOperationState> close(String operationGuid) async {
    await local.close(
      operationGuid: operationGuid,
      userId: await _currentUserId(),
    );
    return getState();
  }

  Future<bool> hasActiveOperation() async => await local.getActive() != null;

  Future<int> _currentUserId() async {
    final token = await secureStorage.read(key: 'token');
    if (token == null || token.isEmpty) {
      throw const BranchOperationException(
        'No fue posible identificar al usuario de la sesión.',
      );
    }
    try {
      final segments = token.split('.');
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      final rawId =
          payload['nameid'] ??
          payload['sub'] ??
          payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'];
      final id = int.tryParse(rawId?.toString() ?? '');
      if (id != null) return id;
    } catch (_) {
      // El mensaje común evita exponer detalles del token al usuario.
    }
    throw const BranchOperationException(
      'La sesión no contiene un identificador de usuario válido.',
    );
  }
}

final branchOperationRepositoryProvider = Provider<BranchOperationRepository>((
  ref,
) {
  return BranchOperationRepository(
    ref.read(branchOperationLocalDataSourceProvider),
    ref.read(secureStorageProvider),
  );
});
