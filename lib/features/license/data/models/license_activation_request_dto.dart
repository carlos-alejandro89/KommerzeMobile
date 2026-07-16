class LicenseActivationRequestDto {
  final String machineId;
  final String licenseKey;
  final String deviceName;

  const LicenseActivationRequestDto({
    required this.machineId,
    required this.licenseKey,
    required this.deviceName,
  });

  Map<String, dynamic> toJson() => {
    'machineId': machineId.trim(),
    'licenseKey': licenseKey.trim(),
    'nombreDispositivo': deviceName.trim(),
  };
}
