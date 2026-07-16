import 'package:kommerze_mobile/features/license/domain/entities/branch_info.dart';

class LicenseActivationResult {
  final bool success;
  final String message;
  final BranchInfo? branch;
  final String? signature;

  const LicenseActivationResult({
    required this.success,
    required this.message,
    this.branch,
    this.signature,
  });
}
