class StoredLicense {
  final String machineId;
  final String deviceName;
  final String licenseKeyHint;
  final int? apiId;
  final String guid;
  final String appVersion;
  final int? validityMonths;
  final bool isActive;
  final DateTime activatedAt;
  final DateTime? expiresAt;

  const StoredLicense({
    required this.machineId,
    required this.deviceName,
    required this.licenseKeyHint,
    required this.apiId,
    required this.guid,
    required this.appVersion,
    required this.validityMonths,
    required this.isActive,
    required this.activatedAt,
    required this.expiresAt,
  });

  factory StoredLicense.fromMap(Map<String, Object?> map) {
    return StoredLicense(
      machineId: map['machine_id']?.toString() ?? '',
      deviceName: map['device_name']?.toString() ?? '',
      licenseKeyHint: map['license_key_hint']?.toString() ?? '',
      apiId: (map['license_api_id'] as num?)?.toInt(),
      guid: map['license_guid']?.toString() ?? '',
      appVersion: map['app_version']?.toString() ?? '',
      validityMonths: (map['validity_months'] as num?)?.toInt(),
      isActive: map['is_active'] == 1,
      activatedAt:
          DateTime.tryParse(map['activated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: DateTime.tryParse(map['expires_at']?.toString() ?? ''),
    );
  }

  bool get isExpired {
    final expiration = expiresAt;
    return expiration != null &&
        DateTime.now().toUtc().isAfter(expiration.toUtc());
  }
}
