class CollectionDashboard {
  final List<CollectionClientSummary> clients;
  final double totalReceivable;
  final double overdueReceivable;
  final double collectedToday;

  const CollectionDashboard({
    required this.clients,
    required this.totalReceivable,
    required this.overdueReceivable,
    required this.collectedToday,
  });
}

class CollectionClientSummary {
  final String clientGuid;
  final String name;
  final String rfc;
  final String phone;
  final double creditLimit;
  final double balance;
  final double overdueBalance;
  final double creditBalance;
  final int openAccounts;
  final DateTime? oldestDueDate;

  const CollectionClientSummary({
    required this.clientGuid,
    required this.name,
    required this.rfc,
    required this.phone,
    required this.creditLimit,
    required this.balance,
    required this.overdueBalance,
    required this.creditBalance,
    required this.openAccounts,
    required this.oldestDueDate,
  });

  double get availableCredit =>
      (creditLimit - balance).clamp(0, double.infinity);
}

class ReceivableAccount {
  final String accountGuid;
  final String orderGuid;
  final int folio;
  final double originalAmount;
  final double paidAmount;
  final DateTime issuedAt;
  final DateTime dueAt;
  final String status;
  final bool blocked;

  const ReceivableAccount({
    required this.accountGuid,
    required this.orderGuid,
    required this.folio,
    required this.originalAmount,
    required this.paidAmount,
    required this.issuedAt,
    required this.dueAt,
    required this.status,
    required this.blocked,
  });

  double get balance => (originalAmount - paidAmount).clamp(0, double.infinity);
  bool get isOverdue => balance > .001 && dueAt.isBefore(DateTime.now());
}

class CollectionClientDetail {
  final CollectionClientSummary client;
  final List<ReceivableAccount> accounts;
  final List<CollectionRecord> collections;
  final List<AccountStatementMovement> statement;

  const CollectionClientDetail({
    required this.client,
    required this.accounts,
    required this.collections,
    required this.statement,
  });
}

enum AccountStatementMovementType { charge, payment }

class AccountStatementMovement {
  final String guid;
  final String? orderGuid;
  final AccountStatementMovementType type;
  final DateTime date;
  final String description;
  final double amount;
  final double runningBalance;

  const AccountStatementMovement({
    required this.guid,
    this.orderGuid,
    required this.type,
    required this.date,
    required this.description,
    required this.amount,
    required this.runningBalance,
  });
}

class PaymentFormOption {
  final String guid;
  final String key;
  final String description;

  const PaymentFormOption({
    required this.guid,
    required this.key,
    required this.description,
  });

  String get label => switch (key) {
    '01' => 'Efectivo',
    '02' => 'Cheque',
    '03' => 'Transferencia',
    '04' || '28' || '29' => 'Tarjeta',
    _ => description,
  };
}

class CollectionPaymentInput {
  final PaymentFormOption paymentForm;
  final double amount;
  final String reference;

  const CollectionPaymentInput({
    required this.paymentForm,
    required this.amount,
    required this.reference,
  });
}

class CollectionAllocation {
  final String accountGuid;
  final String orderGuid;
  final int folio;
  final DateTime dueAt;
  final double previousBalance;
  final double appliedAmount;

  const CollectionAllocation({
    required this.accountGuid,
    required this.orderGuid,
    required this.folio,
    required this.dueAt,
    required this.previousBalance,
    required this.appliedAmount,
  });

  double get resultingBalance =>
      (previousBalance - appliedAmount).clamp(0, double.infinity);
}

class CollectionPreview {
  final double receivedAmount;
  final double appliedAmount;
  final double creditBalance;
  final List<CollectionAllocation> allocations;

  const CollectionPreview({
    required this.receivedAmount,
    required this.appliedAmount,
    required this.creditBalance,
    required this.allocations,
  });
}

class CollectionRecord {
  final String collectionGuid;
  final DateTime date;
  final double total;
  final double applied;
  final double creditBalance;
  final String reference;
  final String userName;
  final bool cancelled;
  final List<String> paymentForms;
  final List<CollectionAppliedSale> appliedSales;

  const CollectionRecord({
    required this.collectionGuid,
    required this.date,
    required this.total,
    required this.applied,
    required this.creditBalance,
    required this.reference,
    required this.userName,
    required this.cancelled,
    required this.paymentForms,
    required this.appliedSales,
  });
}

class CollectionAppliedSale {
  final String accountGuid;
  final String orderGuid;
  final int folio;
  final double appliedAmount;

  const CollectionAppliedSale({
    required this.accountGuid,
    required this.orderGuid,
    required this.folio,
    required this.appliedAmount,
  });
}

class CollectionReceipt {
  final String collectionGuid;
  final DateTime date;
  final String clientName;
  final CollectionPreview preview;
  final List<CollectionPaymentInput> payments;

  const CollectionReceipt({
    required this.collectionGuid,
    required this.date,
    required this.clientName,
    required this.preview,
    required this.payments,
  });
}
