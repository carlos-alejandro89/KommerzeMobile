import 'package:kommerze_mobile/features/sync/domain/entities/payment_form.dart';

class PaymentFormDto {
  const PaymentFormDto._();

  static PaymentForm fromJson(Map<String, dynamic> json) => PaymentForm(
    id: _integer(json['id']),
    key: json['clave']?.toString() ?? '',
    description: json['descripcion']?.toString() ?? '',
    isActive: json['isActive'] == true || json['isActive'] == 1,
    guid: json['guid']?.toString() ?? '',
    createdAt:
        _date(json['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: _meaningfulDate(json['updatedAt']),
    deletedAt: _meaningfulDate(json['deletedAt']),
  );

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static DateTime? _date(Object? value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : DateTime.tryParse(text);
  }

  static DateTime? _meaningfulDate(Object? value) {
    final date = _date(value);
    return date == null || date.year <= 1 ? null : date;
  }
}
