class SaleDetailItem {
  final String levelGuid;
  final String code;
  final String name;
  final String barcode;
  final String imagePath;
  final double quantity;
  final double unitPrice;
  final double discountPercentage;

  const SaleDetailItem({
    required this.levelGuid,
    required this.code,
    required this.name,
    required this.barcode,
    this.imagePath = '',
    required this.quantity,
    required this.unitPrice,
    required this.discountPercentage,
  });

  double get subtotal => quantity * unitPrice;
  double get discount => subtotal * discountPercentage / 100;
  double get total => subtotal - discount;
}

class SaleDetailPayment {
  final String guid;
  final String paymentFormKey;
  final String paymentFormDescription;
  final DateTime paidAt;
  final double amount;
  final bool isCredit;

  const SaleDetailPayment({
    required this.guid,
    required this.paymentFormKey,
    required this.paymentFormDescription,
    required this.paidAt,
    required this.amount,
    required this.isCredit,
  });

  String get label => switch (paymentFormKey) {
    '01' => 'Efectivo',
    '02' => 'Cheque',
    '03' => 'Transferencia',
    '04' || '28' || '29' => 'Tarjeta',
    '99' when isCredit => 'Crédito',
    _ => paymentFormDescription,
  };
}

class SaleDetail {
  final String orderGuid;
  final int folio;
  final DateTime date;
  final bool isCredit;
  final bool sent;
  final String clientName;
  final String clientRfc;
  final String statusName;
  final String orderTypeName;
  final String branchName;
  final List<SaleDetailItem> items;
  final List<SaleDetailPayment> payments;

  const SaleDetail({
    required this.orderGuid,
    required this.folio,
    required this.date,
    required this.isCredit,
    required this.sent,
    required this.clientName,
    required this.clientRfc,
    required this.statusName,
    required this.orderTypeName,
    required this.branchName,
    required this.items,
    required this.payments,
  });

  String get formattedFolio => 'VTA-${folio.toString().padLeft(6, '0')}';
  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get discount => items.fold(0, (sum, item) => sum + item.discount);
  double get total => items.fold(0, (sum, item) => sum + item.total);
  double get paid => payments.fold(0, (sum, payment) => sum + payment.amount);
}
