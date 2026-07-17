import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_detail.dart';

class SaleReceiptPdfService {
  const SaleReceiptPdfService._();

  static Future<void> printReceipt(SaleDetail sale) async {
    await Printing.layoutPdf(
      name: 'Venta ${sale.formattedFolio}',
      onLayout: (_) => build(sale),
    );
  }

  static Future<void> shareReceipt(SaleDetail sale) async {
    await Printing.sharePdf(
      bytes: await build(sale),
      filename: '${sale.formattedFolio}.pdf',
    );
  }

  static Future<Uint8List> build(SaleDetail sale) async {
    final fonts = await _loadFonts();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    );
    final receiptHeight =
        (126 + (sale.items.length * 22) + (sale.payments.length * 12)) *
        PdfPageFormat.mm;
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          receiptHeight,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (_) => pw.DefaultTextStyle(
          style: const pw.TextStyle(fontSize: 8.5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'KOMMERZE',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                sale.branchName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'COMPROBANTE DE VENTA',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7.5),
              ),
              _separator(),
              _dataRow('FOLIO', sale.formattedFolio),
              _dataRow('FECHA', _date(sale.date)),
              _dataRow('CLIENTE', sale.clientName),
              if (sale.clientRfc.isNotEmpty) _dataRow('RFC', sale.clientRfc),
              _dataRow('MODALIDAD', sale.isCredit ? 'CRÉDITO' : 'CONTADO'),
              _dataRow('ESTATUS', sale.statusName.toUpperCase()),
              _separator(),
              pw.Text(
                'ARTÍCULOS',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              for (final item in sale.items) _receiptItem(item),
              _separator(),
              _totalRow('SUBTOTAL', sale.subtotal),
              if (sale.discount > 0) _totalRow('DESCUENTO', -sale.discount),
              pw.SizedBox(height: 2),
              _totalRow('TOTAL', sale.total, emphasized: true),
              _separator(),
              pw.Text(
                'PAGOS',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              if (sale.payments.isEmpty)
                pw.Text('SIN PAGOS REGISTRADOS', textAlign: pw.TextAlign.center)
              else
                for (final payment in sale.payments)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(payment.label.toUpperCase()),
                        ),
                        pw.Text(
                          _money(payment.amount),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              pw.SizedBox(height: 3),
              _totalRow('TOTAL PAGADO', sale.paid),
              _separator(),
              pw.SizedBox(height: 3),
              pw.Text(
                '¡GRACIAS POR SU COMPRA!',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Kommerze · Vende · Gestiona · Crece',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  static Future<_PdfFonts> _loadFonts() async {
    try {
      return _PdfFonts(
        await PdfGoogleFonts.notoSansRegular(),
        await PdfGoogleFonts.notoSansBold(),
      );
    } catch (_) {
      return _PdfFonts(pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  static pw.Widget _dataRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 52,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(child: pw.Text(value)),
      ],
    ),
  );

  static pw.Widget _receiptItem(SaleDetailItem item) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 7),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          item.name.toUpperCase(),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        if (item.code.isNotEmpty)
          pw.Text(item.code, style: const pw.TextStyle(fontSize: 7)),
        pw.SizedBox(height: 2),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                '${_quantity(item.quantity)} x ${_money(item.unitPrice)}',
              ),
            ),
            pw.Text(
              _money(item.total),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    ),
  );

  static pw.Widget _separator() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Text(
      '------------------------------------------',
      maxLines: 1,
      textAlign: pw.TextAlign.center,
      style: const pw.TextStyle(fontSize: 6, letterSpacing: .25),
    ),
  );

  static pw.Widget _totalRow(
    String label,
    double value, {
    bool emphasized = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: emphasized ? 11 : 8.5,
              fontWeight: emphasized ? pw.FontWeight.bold : null,
            ),
          ),
        ),
        pw.Text(
          _money(value),
          style: pw.TextStyle(
            fontSize: emphasized ? 13 : 8.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  static String _money(double value) => '\$${value.toStringAsFixed(2)}';
  static String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _PdfFonts {
  final pw.Font regular;
  final pw.Font bold;
  const _PdfFonts(this.regular, this.bold);
}
