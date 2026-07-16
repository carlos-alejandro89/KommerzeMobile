class StoredBranch {
  final int id;
  final String code;
  final String name;
  final String address;
  final String city;
  final String state;
  final String postalCode;
  final String phone;
  final String email;
  final String cfdiSeries;
  final String guid;

  const StoredBranch({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.phone,
    required this.email,
    required this.cfdiSeries,
    required this.guid,
  });

  factory StoredBranch.fromMap(Map<String, Object?> map) {
    final addressParts =
        [map['calle'], map['exterior'], map['interior'], map['colonia']]
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty);
    return StoredBranch(
      id: (map['id'] as num?)?.toInt() ?? 0,
      code: map['clave']?.toString() ?? '',
      name: map['nombre_sucursal']?.toString() ?? '',
      address: addressParts.join(', '),
      city: map['ciudad']?.toString() ?? '',
      state: map['estado']?.toString() ?? '',
      postalCode: map['codigo_postal']?.toString() ?? '',
      phone: map['telefono']?.toString() ?? '',
      email: map['correo']?.toString() ?? '',
      cfdiSeries: map['serie_cfdi']?.toString() ?? '',
      guid: map['guid']?.toString() ?? '',
    );
  }
}
