class SalePaymentIdentifier {
  final String key;
  final String description;

  const SalePaymentIdentifier({required this.key, required this.description});
}

class SaleHistoryItem {
  final String orderGuid;
  final int folio;
  final DateTime date;
  final bool isCredit;
  final bool sent;
  final String clientName;
  final String statusName;
  final String orderTypeName;
  final double total;
  final double units;
  final double collectedAmount;
  final double creditAmount;
  final List<SalePaymentIdentifier> paymentForms;

  const SaleHistoryItem({
    required this.orderGuid,
    required this.folio,
    required this.date,
    required this.isCredit,
    required this.sent,
    required this.clientName,
    required this.statusName,
    required this.orderTypeName,
    required this.total,
    required this.units,
    this.collectedAmount = 0,
    this.creditAmount = 0,
    this.paymentForms = const [],
  });

  String get formattedFolio {
    final prefix = orderTypeName.toLowerCase() == 'venta' ? 'VTA' : 'PED';
    return '$prefix-${folio.toString().padLeft(6, '0')}';
  }

  String get paymentLabel {
    if (paymentForms.length > 1) return 'Multipago';
    if (paymentForms.isEmpty) return isCredit ? 'Crédito' : 'Sin pago';
    return switch (paymentForms.first.key) {
      '01' => 'Efectivo',
      '02' => 'Cheque',
      '03' => 'Transferencia',
      '04' || '28' || '29' => 'Tarjeta',
      '99' when isCredit => 'Crédito',
      _ => paymentForms.first.description,
    };
  }
}

class SalesHistorySummary {
  final int sales;
  final double total;
  final double cashTotal;
  final double creditTotal;

  const SalesHistorySummary({
    required this.sales,
    required this.total,
    required this.cashTotal,
    required this.creditTotal,
  });

  factory SalesHistorySummary.fromItems(List<SaleHistoryItem> items) =>
      SalesHistorySummary(
        sales: items.length,
        total: items.fold(0, (sum, item) => sum + item.total),
        cashTotal: items.fold(0, (sum, item) => sum + item.collectedAmount),
        creditTotal: items.fold(0, (sum, item) => sum + item.creditAmount),
      );
}
