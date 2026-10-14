class SalePaymentDraft {
  final String paymentFormKey;
  final double amount;
  final bool isCredit;
  final DateTime paidAt;
  final double amountReceived;
  final double change;
  final double balance;

  const SalePaymentDraft({
    required this.paymentFormKey,
    required this.amount,
    required this.isCredit,
    required this.paidAt,
    double? amountReceived,
    this.change = 0,
    this.balance = 0,
  }) : amountReceived = amountReceived ?? amount;

  SalePaymentDraft applied({required double amount, required double balance}) =>
      SalePaymentDraft(
        paymentFormKey: paymentFormKey,
        amount: amount,
        isCredit: isCredit,
        paidAt: paidAt,
        amountReceived: amountReceived,
        change: (amountReceived - amount).clamp(0, double.infinity).toDouble(),
        balance: balance,
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
    remaining -= amount;
    applied.add(payment.applied(amount: amount, balance: remaining));
  }
  return applied;
}
