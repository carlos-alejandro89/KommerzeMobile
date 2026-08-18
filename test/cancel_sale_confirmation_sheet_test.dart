import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_history_item.dart';
import 'package:kommerze_mobile/features/sales_history/presentation/widgets/cancel_sale_confirmation_sheet.dart';

void main() {
  testWidgets('cancela una venta mediante confirmación deslizable', (
    tester,
  ) async {
    var confirmed = false;
    final sale = SaleHistoryItem(
      orderGuid: 'sale-guid',
      folio: 12,
      date: DateTime(2026, 8, 17, 10),
      isCredit: false,
      sent: true,
      clientName: 'Público General',
      statusName: 'Confirmado',
      orderTypeName: 'Venta',
      total: 150,
      units: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCancelSaleConfirmationSheet(
                context: context,
                sale: sale,
                onConfirm: () async => confirmed = true,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar venta'), findsOneWidget);

    await tester.drag(find.text('Desliza para cancelar'), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 350));

    expect(confirmed, isTrue);
    expect(find.text('Venta cancelada'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text('Venta cancelada'), findsNothing);
  });
}
