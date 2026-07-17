enum PaymentMethod { cash, card, transfer, check, credit, other }

extension PaymentMethodInfo on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.cash => 'Efectivo',
    PaymentMethod.card => 'Tarjeta',
    PaymentMethod.transfer => 'Transferencia',
    PaymentMethod.check => 'Cheque',
    PaymentMethod.credit => 'Crédito',
    PaymentMethod.other => 'Otro',
  };
}

class SalePayment {
  final String id;
  final PaymentMethod method;
  final double amount;
  final String reference;
  final DateTime createdAt;

  const SalePayment({
    required this.id,
    required this.method,
    required this.amount,
    required this.reference,
    required this.createdAt,
  });
}
