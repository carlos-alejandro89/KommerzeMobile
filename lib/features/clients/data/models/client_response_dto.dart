import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';

class ClientResponseDto {
  const ClientResponseDto._();

  static Client fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    return Client(
      guid: json['guid']?.toString() ?? '',
      name: json['razonSocial']?.toString() ?? '',
      rfc: json['rfc']?.toString() ?? '',
      email: json['correo']?.toString() ?? '',
      phone: json['telefono']?.toString() ?? '',
      creditAmount: _decimal(json['creditoMaximo']),
      creditDays: _integer(json['diasCredito']),
      isActive: json['deletedAt'] == null,
      createdAt: _date(json['createdAt']) ?? now,
      updatedAt: _date(json['updatedAt']) ?? now,
    );
  }

  static double _decimal(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static DateTime? _date(Object? value) {
    final text = value?.toString();
    final date = text == null || text.isEmpty ? null : DateTime.tryParse(text);
    return date == null || date.year <= 1 ? null : date;
  }
}
