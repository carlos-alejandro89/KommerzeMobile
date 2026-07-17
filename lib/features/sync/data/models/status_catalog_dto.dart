import 'package:kommerze_mobile/features/sync/domain/entities/status_catalog.dart';

class StatusCatalogDto {
  const StatusCatalogDto._();

  static StatusCatalog fromJson(Map<String, dynamic> json) => StatusCatalog(
    id: _integer(json['id']),
    name: json['nombre']?.toString() ?? '',
    guid: json['guid']?.toString() ?? '',
    createdAt: _meaningfulDate(json['createdAt']),
    updatedAt: _meaningfulDate(json['updatedAt']),
    deletedAt: _meaningfulDate(json['deletedAt']),
  );

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static DateTime? _meaningfulDate(Object? value) {
    final text = value?.toString();
    final date = text == null || text.isEmpty ? null : DateTime.tryParse(text);
    return date == null || date.year <= 1 ? null : date;
  }
}
