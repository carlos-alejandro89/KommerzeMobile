class SaleOrderDetail {
  final String levelGuid;
  final double quantity;
  final double purchasePrice;
  final double salePrice;
  final double salePrice2;
  final double discount;
  final double vatTransfer;
  final double vatRate;
  final double incomeTaxWithholding;
  final double incomeTaxRate;
  final String additionalInfo;

  const SaleOrderDetail({
    required this.levelGuid,
    required this.quantity,
    required this.purchasePrice,
    required this.salePrice,
    required this.salePrice2,
    required this.discount,
    this.vatTransfer = 0,
    this.vatRate = 0,
    this.incomeTaxWithholding = 0,
    this.incomeTaxRate = 0,
    this.additionalInfo = '',
  });
}

class SaleOrderPayment {
  final String paymentFormGuid;
  final DateTime date;
  final double amount;
  final double amountReceived;
  final double change;
  final double balance;

  const SaleOrderPayment({
    required this.paymentFormGuid,
    required this.date,
    required this.amount,
    required this.amountReceived,
    required this.change,
    required this.balance,
  });
}

class SaleOrder {
  final String branchOriginGuid;
  final String orderGuid;
  final String statusGuid;
  final String clientGuid;
  final String orderTypeGuid;
  final int folio;
  final DateTime date;
  final bool isCredit;
  final bool sync;
  final bool sent;
  final List<SaleOrderDetail> details;
  final List<SaleOrderPayment> payments;

  const SaleOrder({
    required this.branchOriginGuid,
    required this.orderGuid,
    required this.statusGuid,
    required this.clientGuid,
    required this.orderTypeGuid,
    required this.folio,
    required this.date,
    required this.isCredit,
    required this.sync,
    required this.sent,
    required this.details,
    this.payments = const [],
  });
}
