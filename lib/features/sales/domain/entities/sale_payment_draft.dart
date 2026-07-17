class SalePaymentDraft {
  final String paymentFormKey;
  final double amount;
  final bool isCredit;
  final DateTime paidAt;

  const SalePaymentDraft({
    required this.paymentFormKey,
    required this.amount,
    required this.isCredit,
    required this.paidAt,
  });

  SalePaymentDraft withAmount(double value) => SalePaymentDraft(
    paymentFormKey: paymentFormKey,
    amount: value,
    isCredit: isCredit,
    paidAt: paidAt,
  );
}

List<SalePaymentDraft> applyPaymentsToTotal(
  List<SalePaymentDraft> payments,
  double total,
) {
  var remaining = total;
  final applied = <SalePaymentDraft>[];
  for (final payment in payments) {
    if (remaining <= .001) break;
    if (payment.amount <= 0) continue;
    final amount = payment.amount > remaining ? remaining : payment.amount;
    applied.add(payment.withAmount(amount));
    remaining -= amount;
  }
  return applied;
}
