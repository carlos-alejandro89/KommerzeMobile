import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';

class ClientRequestDto {
  final String guid;
  final ClientDraft draft;

  const ClientRequestDto({required this.guid, required this.draft});

  Map<String, dynamic> toJson() => {
    'guid': guid,
    'nombre': draft.name.trim(),
    'rfc': draft.rfc.trim().toUpperCase(),
    'correo': draft.email.trim().toLowerCase(),
    'telefono': draft.phone.trim(),
    'montoCredito': draft.creditAmount,
    'diasCredito': draft.creditDays,
  };
}
