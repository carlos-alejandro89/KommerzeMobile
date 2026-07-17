import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';

class InventoryDto {
  const InventoryDto._();

  static InventoryItem fromPrice(Map<String, dynamic> json) {
    return _fromJson(json, initialStock: 0);
  }

  static InventoryItem fromBackup(Map<String, dynamic> json) {
    return _fromJson(json, initialStock: _decimal(json['existencia']));
  }

  static InventoryItem _fromJson(
    Map<String, dynamic> json, {
    required double initialStock,
  }) {
    return InventoryItem(
      code: _text(json['codigo']),
      description: json['descripcion']?.toString(),
      packageLevel: _text(json['nivelEmpaque'] ?? json['nombreEmpaque']),
      barcode: _text(json['codigoBarras']),
      imagePath: _text(json['imgReferencia']),
      purchasePrice: _decimal(json['precioCompra']),
      salePrice: _decimal(json['precioVenta']),
      discountPercentage: _percentage(json['porcentajeDescuento']),
      stock: initialStock,
      lineName: _text(json['nombreLinea'], fallback: 'SIN LINEA'),
      brandName: _text(json['nombreMarca'], fallback: 'SIN MARCA'),
      levelGuid: _text(json['nivelGuid']),
      productGuid: _text(json['productoGuid']),
      packageGuid: json['empaqueGuid']?.toString(),
    );
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static double _decimal(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static double _percentage(Object? value) {
    final percentage = _decimal(value);
    if (!percentage.isFinite || percentage < 0 || percentage > 100) return 0;
    return percentage;
  }
}
