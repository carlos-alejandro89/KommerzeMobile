import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    final pdf = await _buildPdf(receipt);
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

  Future<Uint8List> _buildPdf(SaleReceipt receipt) async {
    final document = pw.Document();
    final height = (120 + receipt.items.length * 18) * PdfPageFormat.mm;
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          height,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'KOMMERZE',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'RECIBO DE VENTA',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 10),
            _row('Folio', receipt.folio),
            _row('Fecha', _date(receipt.order.date)),
            _row('Cliente', receipt.client.name),
            _divider(),
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
            _row('Subtotal', _money(receipt.subtotal)),
            if (receipt.discount > 0)
              _row('Descuento', '-${_money(receipt.discount)}'),
            pw.SizedBox(height: 3),
            pw.DefaultTextStyle(
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              child: _row('TOTAL', _money(receipt.total)),
            ),
            _divider(),
            _row('Total pagado', _money(receipt.paid)),
            pw.SizedBox(height: 14),
            pw.Text(
              '¡GRACIAS POR SU COMPRA!',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Kommerze · Vende · Gestiona · Crece',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }

  pw.Widget _row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: pw.Text(label)),
        pw.SizedBox(width: 8),
        pw.Text(value),
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
