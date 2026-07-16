import 'package:kommerze_mobile/features/license/domain/entities/stored_branch.dart';
import 'package:kommerze_mobile/features/license/domain/entities/stored_license.dart';

class LicenseDetails {
  final StoredLicense license;
  final StoredBranch branch;

  const LicenseDetails({required this.license, required this.branch});
}
