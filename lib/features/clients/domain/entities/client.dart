class Client {
  final String guid;
  final String name;
  final String rfc;
  final String email;
  final String phone;
  final double creditAmount;
  final int creditDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Client({
    required this.guid,
    required this.name,
    required this.rfc,
    required this.email,
    required this.phone,
    required this.creditAmount,
    required this.creditDays,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Client.fromMap(Map<String, Object?> map) => Client(
    guid: map['guid']?.toString() ?? '',
    name: map['nombre']?.toString() ?? '',
    rfc: map['rfc']?.toString() ?? '',
    email: map['correo']?.toString() ?? '',
    phone: map['telefono']?.toString() ?? '',
    creditAmount: _decimal(map['monto_credito']),
    creditDays: _integer(map['dias_credito']),
    isActive: map['activo'] == 1,
    createdAt: DateTime.parse(map['created_at'].toString()),
    updatedAt: DateTime.parse(map['updated_at'].toString()),
  );

  static double _decimal(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

class ClientDraft {
  final String name;
  final String rfc;
  final String email;
  final String phone;
  final double creditAmount;
  final int creditDays;

  const ClientDraft({
    required this.name,
    required this.rfc,
    required this.email,
    required this.phone,
    required this.creditAmount,
    required this.creditDays,
  });
}
