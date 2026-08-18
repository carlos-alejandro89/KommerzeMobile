class CustomerLoan {
  final String guid;
  final String clientGuid;
  final String clientName;
  final DateTime date;
  final DateTime dueDate;
  final double amount;
  final double paid;
  final String concept;
  final bool blocked;

  const CustomerLoan({
    required this.guid,
    required this.clientGuid,
    required this.clientName,
    required this.date,
    required this.dueDate,
    required this.amount,
    required this.paid,
    required this.concept,
    required this.blocked,
  });

  double get balance => (amount - paid).clamp(0, double.infinity);
  bool get isPaid => balance <= .001;
  bool get isOverdue => !isPaid && dueDate.isBefore(DateTime.now());
}

class CustomerLoanDraft {
  final String clientGuid;
  final double amount;
  final DateTime dueDate;
  final String concept;

  const CustomerLoanDraft({
    required this.clientGuid,
    required this.amount,
    required this.dueDate,
    required this.concept,
  });
}
