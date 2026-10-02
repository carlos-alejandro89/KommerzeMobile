import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:kommerze_mobile/features/printer/domain/entities/printer_settings.dart';
import 'package:kommerze_mobile/features/printer/domain/entities/sale_receipt.dart';
import 'package:kommerze_mobile/features/printer/presentation/controllers/printer_settings_controller.dart';

class ReceiptEmailService {
  final FlutterSecureStorage secureStorage;
  const ReceiptEmailService(this.secureStorage);

  Future<void> send(SaleReceipt receipt, PrinterSettings settings) async {
    final destination = receipt.client.email.trim();
    if (destination.isEmpty) {
      throw const ReceiptEmailException(
        'El cliente seleccionado no tiene un correo registrado.',
      );
    }
    if (!settings.isEmailConfigured) {
      throw const ReceiptEmailException(
        'Configura el servidor y las credenciales de correo antes de enviar.',
      );
    }
    final password = await secureStorage.read(
      key: PrinterSettingsController.smtpPasswordKey,
    );
    if (password == null || password.isEmpty) {
      throw const ReceiptEmailException(
        'Configura la contraseña del servidor de correo antes de enviar.',
      );
    }

    final smtp = SmtpServer(
      settings.smtpServer,
      port: settings.smtpPort,
      username: settings.smtpUsername,
      password: password,
      ssl: settings.smtpSecurity == SmtpSecurity.sslTls,
      allowInsecure: settings.smtpSecurity == SmtpSecurity.none,
    );
    final pdf = await _buildPdf(receipt, settings);
    final message = mailer.Message()
      ..from = mailer.Address(settings.senderEmail, settings.senderName)
      ..recipients.add(destination)
      ..subject = 'Recibo de venta ${receipt.folio}'
      ..text = _plainText(receipt)
      ..html = _html(receipt)
      ..attachments.add(
        mailer.StreamAttachment(
          Stream<List<int>>.value(pdf),
          'application/pdf',
          fileName: '${receipt.folio}.pdf',
        ),
      );

    try {
      await mailer.send(message, smtp, timeout: const Duration(seconds: 20));
    } on mailer.MailerException catch (error) {
      final details = error.problems.map((problem) => problem.msg).join(' ');
      throw ReceiptEmailException(
        details.isEmpty
            ? 'El servidor SMTP rechazó el envío.'
            : 'No se pudo enviar el recibo: $details',
      );
    } on TimeoutException {
      throw const ReceiptEmailException(
        'El servidor de correo no respondió a tiempo.',
      );
    } catch (error) {
      throw ReceiptEmailException('No se pudo enviar el recibo: $error');
    }
  }

  Future<Uint8List> _buildPdf(
    SaleReceipt receipt,
    PrinterSettings settings,
  ) async {
    final document = pw.Document();
    final height =
        (105 + receipt.items.length * 16 + settings.legends.length * 15) *
        PdfPageFormat.mm;
    pw.MemoryImage? logo;
    if (settings.includeLogo) {
      try {
        final bytes = settings.logoBase64.isNotEmpty
            ? base64Decode(settings.logoBase64)
            : (await rootBundle.load(
                'assets/icon/app_icon.png',
              )).buffer.asUint8List();
        logo = pw.MemoryImage(bytes);
      } catch (_) {}
    }
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          settings.paperWidthMm * PdfPageFormat.mm,
          height,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (logo != null) ...[
              pw.Center(
                child: pw.Image(
                  logo,
                  width: 42 * PdfPageFormat.mm,
                  height: 16 * PdfPageFormat.mm,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 4),
            ],
            pw.Text(
              settings.businessName.trim().isEmpty
                  ? 'KOMMERZE'
                  : settings.businessName.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            if (settings.showBranchName && receipt.branchName.isNotEmpty)
              pw.Text(receipt.branchName, textAlign: pw.TextAlign.center),
            if (settings.showBranchAddress && receipt.branchAddress.isNotEmpty)
              pw.Text(receipt.branchAddress, textAlign: pw.TextAlign.center),
            if (settings.showBranchPhone && receipt.branchPhone.isNotEmpty)
              pw.Text(receipt.branchPhone, textAlign: pw.TextAlign.center),
            if (settings.showBranchEmail && receipt.branchEmail.isNotEmpty)
              pw.Text(receipt.branchEmail, textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 10),
            _divider(),
            _row('Folio:', receipt.order.folio.toString()),
            _row('Fecha:', _date(receipt.order.date)),
            _row('Cajero:', receipt.cashierName),
            _row('Cliente:', receipt.client.name),
            _divider(),
            _row('Descripción', 'Importe', bold: true),
            for (final item in receipt.items) ...[
              pw.Text(
                item.product.displayName,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              _row(
                '${_quantity(item.quantity)} x ${_money(item.unitPrice)}',
                _money(item.total),
              ),
              pw.SizedBox(height: 5),
            ],
            _divider(),
            _row('Subtotal:', _money(receipt.subtotal)),
            _row('Descuento:', _money(receipt.discount)),
            pw.SizedBox(height: 3),
            pw.DefaultTextStyle(
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              child: _row('TOTAL:', _money(receipt.total)),
            ),
            _row('Pago:', _money(receipt.paid)),
            _row(
              'Cambio:',
              _money((receipt.paid - receipt.total).clamp(0, double.infinity)),
            ),
            _divider(),
            for (var index = 0; index < settings.legends.length; index++) ...[
              if (index > 0) _divider(),
              pw.Text(
                settings.legends[index].text,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontWeight: settings.legends[index].bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return document.save();
  }

  pw.Widget _row(String label, String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  pw.Widget _divider() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 7),
    child: pw.Divider(borderStyle: pw.BorderStyle.dashed),
  );

  String _plainText(SaleReceipt receipt) => [
    'Hola ${receipt.client.name},',
    '',
    'Adjuntamos tu recibo de venta ${receipt.folio}.',
    'Total: ${_money(receipt.total)}',
    '',
    'Gracias por tu compra.',
    'Kommerze - Vende, gestiona y crece',
  ].join('\n');

  String _html(SaleReceipt receipt) =>
      '''
    <h2>Gracias por tu compra, ${_escape(receipt.client.name)}</h2>
    <p>Adjuntamos tu recibo de venta <strong>${receipt.folio}</strong>.</p>
    <p>Total: <strong>${_money(receipt.total)}</strong></p>
    <p>Kommerze · Vende · Gestiona · Crece</p>
  ''';

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class ReceiptEmailException implements Exception {
  final String message;
  const ReceiptEmailException(this.message);
  @override
  String toString() => message;
}
