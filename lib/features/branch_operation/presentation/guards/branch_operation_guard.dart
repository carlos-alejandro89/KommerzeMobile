import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/features/branch_operation/presentation/controllers/branch_operation_controller.dart';

class BranchOperationGuard {
  BranchOperationGuard._();

  static Future<bool> ensureOpen(BuildContext context, WidgetRef ref) async {
    final isOpen = await ref.read(activeBranchOperationProvider.future);
    if (!context.mounted) return false;
    if (!isOpen) {
      await context.push(AppConstants.branchOperationScreenRoute);
      return false;
    }
    return true;
  }
}
