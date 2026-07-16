class LicenseInfo {
  final int id;
  final String guid;
  final String deviceName;
  final String licenseKey;
  final String appVersion;
  final String machineId;
  final int validityMonths;
  final DateTime? activationDate;
  final DateTime? expirationDate;

  const LicenseInfo({
    required this.id,
    required this.guid,
    required this.deviceName,
    required this.licenseKey,
    required this.appVersion,
    required this.machineId,
    required this.validityMonths,
    required this.activationDate,
    required this.expirationDate,
  });
}
