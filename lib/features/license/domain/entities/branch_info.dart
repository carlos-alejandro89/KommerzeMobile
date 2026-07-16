import 'package:kommerze_mobile/features/license/domain/entities/license_info.dart';

class BranchInfo {
  final int id;
  final int companyId;
  final int? priceListId;
  final int licenseId;
  final String code;
  final String name;
  final String street;
  final String exterior;
  final String? interior;
  final String neighborhood;
  final String city;
  final String state;
  final String postalCode;
  final String phone;
  final String email;
  final String cfdiSeries;
  final double salesCommission;
  final double inventoryValue;
  final String guid;
  final LicenseInfo license;

  const BranchInfo({
    required this.id,
    required this.companyId,
    required this.priceListId,
    required this.licenseId,
    required this.code,
    required this.name,
    required this.street,
    required this.exterior,
    required this.interior,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.phone,
    required this.email,
    required this.cfdiSeries,
    required this.salesCommission,
    required this.inventoryValue,
    required this.guid,
    required this.license,
  });
}
