class InventoryItem {
  final String code;
  final String? description;
  final String packageLevel;
  final String barcode;
  final String imagePath;
  final double purchasePrice;
  final double salePrice;
  final double discountPercentage;
  final double stock;
  final String lineName;
  final String brandName;
  final String levelGuid;
  final String productGuid;
  final String? packageGuid;

  const InventoryItem({
    required this.code,
    required this.description,
    required this.packageLevel,
    required this.barcode,
    this.imagePath = '',
    required this.purchasePrice,
    required this.salePrice,
    required this.discountPercentage,
    required this.stock,
    required this.lineName,
    required this.brandName,
    required this.levelGuid,
    required this.productGuid,
    required this.packageGuid,
  });

  String get displayName {
    final value = description?.trim();
    return value == null || value.isEmpty ? code : value;
  }

  factory InventoryItem.fromMap(Map<String, Object?> map) {
    return InventoryItem(
      code: map['codigo']?.toString() ?? '',
      description: map['descripcion']?.toString(),
      packageLevel: map['nivel_empaque']?.toString() ?? '',
      barcode: map['codigo_barras']?.toString() ?? '',
      imagePath: map['img_referencia']?.toString() ?? '',
      purchasePrice: _number(map['precio_compra']),
      salePrice: _number(map['precio_venta']),
      discountPercentage: _percentage(map['porcentaje_descuento']),
      stock: _number(map['existencia']),
      lineName: map['nombre_linea']?.toString() ?? 'SIN LINEA',
      brandName: map['nombre_marca']?.toString() ?? 'SIN MARCA',
      levelGuid: map['nivel_guid']?.toString() ?? '',
      productGuid: map['producto_guid']?.toString() ?? '',
      packageGuid: map['empaque_guid']?.toString(),
    );
  }

  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static double _percentage(Object? value) {
    final percentage = _number(value);
    if (!percentage.isFinite || percentage < 0 || percentage > 100) return 0;
    return percentage;
  }
}
