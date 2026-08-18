import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:kommerze_mobile/features/reports/domain/entities/profit_report.dart';

class ProfitReportPdfService {
  const ProfitReportPdfService._();

  static Future<void> share(ProfitOperationDetail detail) async {
    await Printing.sharePdf(
      bytes: await build(detail),
      filename:
          'utilidad-${DateFormat('yyyyMMdd-HHmm').format(detail.operation.startedAt)}.pdf',
    );
  }

  static Future<Uint8List> build(ProfitOperationDetail detail) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text(
            'KOMMERZE',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Reporte de utilidades',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(detail.operation.branchName),
          pw.Text(
            'Operación: ${_date(detail.operation.startedAt)} - ${detail.operation.endedAt == null ? 'En curso' : _date(detail.operation.endedAt!)}',
          ),
          pw.Text('Apertura: ${detail.operation.openedBy}'),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _metric('Venta neta', detail.operation.netSales),
              _metric('Costo', detail.operation.cost),
              _metric('Utilidad', detail.operation.profit),
              _metric('Margen', detail.operation.profitMargin, percent: true),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Folio',
              'Fecha',
              'Cliente',
              'Venta neta',
              'Costo',
              'Utilidad',
              'Margen',
            ],
            data: detail.sales
                .map(
                  (sale) => [
                    sale.formattedFolio,
                    DateFormat('dd/MM/yyyy HH:mm').format(sale.date),
                    sale.clientName,
                    _money(sale.net),
                    _money(sale.cost),
                    _money(sale.profit),
                    _percent(sale.profitMargin),
                  ],
                )
                .toList(),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF073E9A),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellPadding: const pw.EdgeInsets.all(5),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Utilidad total: ${_money(detail.operation.profit)}  |  Margen: ${_percent(detail.operation.profitMargin)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _metric(
    String label,
    double amount, {
    bool percent = false,
  }) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.all(10),
      color: PdfColors.grey100,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            percent ? _percent(amount) : _money(amount),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  static String _date(DateTime date) =>
      DateFormat('dd/MM/yyyy HH:mm').format(date);
  static String _money(double value) =>
      NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(value);
  static String _percent(double value) => '${value.toStringAsFixed(1)}%';
}
