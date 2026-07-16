import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/branch_operation/data/repositories/branch_operation_repository.dart';
import 'package:kommerze_mobile/features/branch_operation/domain/entities/branch_operation_state.dart';

class BranchOperationController extends AsyncNotifier<BranchOperationState> {
  @override
  Future<BranchOperationState> build() {
    return ref.read(branchOperationRepositoryProvider).getState();
  }

  Future<bool> open({
    required double initialCashAmount,
    required String? notes,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(branchOperationRepositoryProvider)
          .open(initialCashAmount: initialCashAmount, notes: notes),
    );
    state = result;
    ref.invalidate(activeBranchOperationProvider);
    return !result.hasError;
  }

  Future<bool> close() async {
    final operation = state.value?.activeOperation;
    if (operation == null) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(branchOperationRepositoryProvider).close(operation.guid),
    );
    state = result;
    ref.invalidate(activeBranchOperationProvider);
    return !result.hasError;
  }
}

final branchOperationControllerProvider =
    AsyncNotifierProvider<BranchOperationController, BranchOperationState>(
      BranchOperationController.new,
    );

final activeBranchOperationProvider = FutureProvider<bool>((ref) {
  return ref.read(branchOperationRepositoryProvider).hasActiveOperation();
});
