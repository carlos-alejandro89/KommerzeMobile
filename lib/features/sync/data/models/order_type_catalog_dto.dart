import 'package:kommerze_mobile/features/sync/domain/entities/order_type_catalog.dart';

class OrderTypeCatalogDto {
  const OrderTypeCatalogDto._();

  static OrderTypeCatalog fromJson(Map<String, dynamic> json) =>
      OrderTypeCatalog(
        id: _integer(json['id']),
        name: json['nombre']?.toString() ?? '',
        description: json['descripcion']?.toString() ?? '',
        icon: json['icon']?.toString(),
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
