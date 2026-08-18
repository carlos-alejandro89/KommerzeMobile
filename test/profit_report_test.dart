import 'package:flutter_test/flutter_test.dart';
import 'package:kommerze_mobile/features/reports/data/services/profit_report_pdf_service.dart';
import 'package:kommerze_mobile/features/reports/domain/entities/profit_report.dart';

void main() {
  test('calcula la utilidad real después del descuento', () {
    final operation = ProfitOperationSummary(
      guid: 'operation-guid',
      startedAt: DateTime(2026, 8, 17, 8),
      endedAt: DateTime(2026, 8, 17, 18),
      openedBy: 'Carlos',
      branchName: 'Matriz',
      salesCount: 1,
      netSales: 180,
      cost: 120,
    );
    final sale = ProfitSaleItem(
      orderGuid: 'order-guid',
      folio: 7,
      date: DateTime(2026, 8, 17, 10),
      clientName: 'Público General',
      gross: 200,
      discount: 20,
      net: 180,
      cost: 120,
    );

    expect(operation.profit, 60);
    expect(operation.profitMargin, closeTo(33.333, .001));
    expect(sale.profit, 60);
    expect(sale.profitMargin, closeTo(33.333, .001));
    expect(sale.formattedFolio, 'VTA-000007');
  });

  test('genera un PDF con la operación y sus ventas', () async {
    final operation = ProfitOperationSummary(
      guid: 'operation-guid',
      startedAt: DateTime(2026, 8, 17, 8),
      endedAt: DateTime(2026, 8, 17, 18),
      openedBy: 'Carlos',
      branchName: 'Matriz',
      salesCount: 1,
      netSales: 180,
      cost: 120,
    );
    final detail = ProfitOperationDetail(
      operation: operation,
      sales: [
        ProfitSaleItem(
          orderGuid: 'order-guid',
          folio: 7,
          date: DateTime(2026, 8, 17, 10),
          clientName: 'Público General',
          gross: 200,
          discount: 20,
          net: 180,
          cost: 120,
        ),
      ],
    );

    final bytes = await ProfitReportPdfService.build(detail);
    expect(bytes, isNotEmpty);
  });
}
