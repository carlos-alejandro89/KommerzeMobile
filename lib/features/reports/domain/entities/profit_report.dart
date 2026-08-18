class ProfitOperationSummary {
  final String guid;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String openedBy;
  final String branchName;
  final int salesCount;
  final double netSales;
  final double cost;

  const ProfitOperationSummary({
    required this.guid,
    required this.startedAt,
    required this.endedAt,
    required this.openedBy,
    required this.branchName,
    required this.salesCount,
    required this.netSales,
    required this.cost,
  });

  double get profit => netSales - cost;
  double get profitMargin =>
      netSales.abs() < .001 ? 0 : (profit / netSales) * 100;
  bool get isOpen => endedAt == null;
}

class ProfitSaleItem {
  final String orderGuid;
  final int folio;
  final DateTime date;
  final String clientName;
  final double gross;
  final double discount;
  final double net;
  final double cost;

  const ProfitSaleItem({
    required this.orderGuid,
    required this.folio,
    required this.date,
    required this.clientName,
    required this.gross,
    required this.discount,
    required this.net,
    required this.cost,
  });

  double get profit => net - cost;
  double get profitMargin => net.abs() < .001 ? 0 : (profit / net) * 100;
  String get formattedFolio => 'VTA-${folio.toString().padLeft(6, '0')}';
}

class ProfitOperationDetail {
  final ProfitOperationSummary operation;
  final List<ProfitSaleItem> sales;

  const ProfitOperationDetail({required this.operation, required this.sales});
}
