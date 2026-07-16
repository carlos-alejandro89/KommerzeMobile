import 'package:kommerze_mobile/features/branch_operation/domain/entities/branch_operation.dart';

class BranchOperationState {
  final BranchOperation? activeOperation;
  final double currentInventoryValue;

  const BranchOperationState({
    required this.activeOperation,
    required this.currentInventoryValue,
  });

  bool get isOpen => activeOperation != null;
}
