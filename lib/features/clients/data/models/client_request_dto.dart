import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';

class ClientRequestDto {
  final ClientDraft draft;

  const ClientRequestDto({required this.draft});

  Map<String, dynamic> toJson() => {
    'razonSocial': draft.name.trim(),
    'rfc': draft.rfc.trim().toUpperCase(),
    'correo': draft.email.trim().toLowerCase(),
    'telefono': draft.phone.trim(),
    'creditoMaximo': draft.creditAmount,
    'diasCredito': draft.creditDays,
  };
}
