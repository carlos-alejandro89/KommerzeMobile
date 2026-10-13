class LicenseActivationRequestDto {
  final String machineId;
  final String licenseKey;
  final String deviceName;

  const LicenseActivationRequestDto({
    required this.machineId,
    required this.licenseKey,
    required this.deviceName,
  });

  static String normalizeLicenseKey(String value) => value
      .trim()
      .replaceAll(RegExp(r'[\s\u200B-\u200D\u2060\uFEFF]'), '')
      .replaceAll(RegExp(r'[\u2010-\u2015\u2212\uFE58\uFE63\uFF0D]'), '-')
      .toUpperCase();

  Map<String, dynamic> toJson() => {
    'machineId': machineId.trim(),
    'licenseKey': normalizeLicenseKey(licenseKey),
    'nombreDispositivo': deviceName.trim(),
  };
}
