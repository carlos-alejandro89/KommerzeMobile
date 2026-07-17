import 'package:kommerze_mobile/features/sync/domain/entities/user_catalog.dart';

class UserCatalogDto {
  const UserCatalogDto._();

  static UserCatalog fromJson(Map<String, dynamic> json) => UserCatalog(
    id: _integer(json['id']),
    profileId: _integer(json['perfilId']),
    name: json['nombre']?.toString() ?? '',
    phone: json['telefono']?.toString() ?? '',
    email: json['correoElectronico']?.toString() ?? '',
    emailConfirmed: json['correoConfirmado'] == true,
    profileImage: json['imgPerfil']?.toString(),
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
