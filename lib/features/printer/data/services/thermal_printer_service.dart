import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:kommerze_mobile/features/printer/domain/entities/printer_settings.dart';
import 'package:kommerze_mobile/features/printer/domain/entities/sale_receipt.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_detail.dart';

class ThermalPrinterService {
  const ThermalPrinterService();

  Future<void> printReceipt(
    SaleReceipt receipt,
    PrinterSettings settings,
  ) async {
    if (!settings.isConfigured) {
      throw const PrinterException(
        'Configura la IP y el puerto de la impresora.',
      );
    }
    Socket? socket;
    try {
      socket = await Socket.connect(
        settings.ipAddress,
        settings.port,
        timeout: const Duration(seconds: 6),
      );
      socket.add(await _buildReceipt(receipt, settings));
      await socket.flush();
    } on SocketException catch (error) {
      throw PrinterException(
        'No fue posible conectar con ${settings.ipAddress}:${settings.port}. ${error.message}',
      );
    } on TimeoutException {
      throw const PrinterException('La miniprinter no respondió a tiempo.');
    } finally {
      await socket?.close();
    }
  }

  Future<void> reprintSale(
    SaleDetail sale,
    PrinterSettings settings, {
    String branchAddress = '',
    String branchPhone = '',
    String branchEmail = '',
    String cashierName = '',
  }) async {
    if (!settings.isConfigured) {
      throw const PrinterException(
        'Configura la IP y el puerto de la impresora.',
      );
    }
    Socket? socket;
    try {
      socket = await Socket.connect(
        settings.ipAddress,
        settings.port,
        timeout: const Duration(seconds: 6),
      );
      socket.add(
        await _buildHistoricalReceipt(
          sale,
          settings,
          branchAddress: branchAddress,
          branchPhone: branchPhone,
          branchEmail: branchEmail,
          cashierName: cashierName,
        ),
      );
      await socket.flush();
    } on SocketException catch (error) {
      throw PrinterException(
        'No fue posible conectar con ${settings.ipAddress}:${settings.port}. ${error.message}',
      );
    } on TimeoutException {
      throw const PrinterException('La miniprinter no respondió a tiempo.');
    } finally {
      await socket?.close();
    }
  }

  Future<Uint8List> _buildHistoricalReceipt(
    SaleDetail sale,
    PrinterSettings settings, {
    required String branchAddress,
    required String branchPhone,
    required String branchEmail,
    required String cashierName,
  }) async {
    final bytes = BytesBuilder();
    final width = settings.paperWidthMm == 58 ? 32 : 42;
    bytes.add([0x1B, 0x40, 0x1B, 0x74, 0x10, 0x1B, 0x4D, 0x00]);
    if (settings.includeLogo) {
      try {
        final logo = settings.logoBase64.isNotEmpty
            ? base64Decode(settings.logoBase64)
            : (await rootBundle.load(
                'assets/icon/app_icon.png',
              )).buffer.asUint8List();
        bytes.add(_rasterLogo(logo, settings.paperWidthMm));
        bytes.add([0x1B, 0x64, 0x01]);
      } catch (_) {}
    }
    _center(bytes);
    _bold(bytes, true);
    bytes.add([0x1D, 0x21, 0x11]);
    _line(
      bytes,
      settings.businessName.trim().isEmpty
          ? 'KOMMERZE'
          : settings.businessName.toUpperCase(),
    );
    bytes.add([0x1D, 0x21, 0x00]);
    _bold(bytes, false);
    if (settings.showBranchName && sale.branchName.trim().isNotEmpty) {
      _wrappedLine(bytes, sale.branchName, width);
    }
    if (settings.showBranchAddress && branchAddress.trim().isNotEmpty) {
      _wrappedLine(bytes, branchAddress, width);
    }
    if (settings.showBranchPhone && branchPhone.trim().isNotEmpty) {
      _wrappedLine(bytes, branchPhone, width);
    }
    if (settings.showBranchEmail && branchEmail.trim().isNotEmpty) {
      _wrappedLine(bytes, branchEmail, width);
    }
    bytes.add([0x1B, 0x4A, 0x0F]);
    _separator(bytes, width);
    bytes.add(_safe('Folio: '));
    _bold(bytes, true);
    _line(bytes, sale.folio.toString());
    _bold(bytes, false);
    _wrappedLine(bytes, 'Fecha: ${_date(sale.date)}', width);
    _wrappedLine(bytes, 'Cajero: $cashierName', width);
    _wrappedLine(bytes, 'Cliente: ${sale.clientName}', width);
    _separator(bytes, width);
    _linePair(bytes, 'Descripción', 'Importe', width);
    for (var index = 0; index < sale.items.length; index++) {
      final item = sale.items[index];
      _left(bytes);
      bytes.add([0x1B, 0x4D, 0x01]);
      _bold(bytes, true);
      _wrappedIndentedLine(
        bytes,
        item.name.toUpperCase(),
        width,
        settings.paperWidthMm == 58 ? '' : '    ',
      );
      _bold(bytes, false);
      bytes.add([0x1B, 0x4D, 0x00]);
      _center(bytes);
      _linePair(
        bytes,
        '${item.quantity.toStringAsFixed(2)} x ${_money(item.unitPrice)}',
        _money(item.total),
        width,
      );
      if (index < sale.items.length - 1) bytes.add([0x1B, 0x4A, 0x02]);
    }
    _separator(bytes, width);
    _linePair(bytes, 'Subtotal:', _money(sale.subtotal), width);
    _linePair(bytes, 'Descuento:', _money(sale.discount), width);
    _bold(bytes, true);
    bytes.add([0x1D, 0x21, 0x01]);
    _linePair(bytes, 'TOTAL:', _money(sale.total), width);
    bytes.add([0x1D, 0x21, 0x00]);
    _bold(bytes, false);
    _line(bytes, '');
    _linePair(bytes, 'Pago:', _money(sale.paid), width);
    _linePair(
      bytes,
      'Cambio:',
      _money((sale.paid - sale.total).clamp(0, double.infinity)),
      width,
    );
    _separator(bytes, width);
    var printedLegend = false;
    for (var index = 0; index < settings.legends.length; index++) {
      final legend = settings.legends[index];
      if (legend.text.trim().isEmpty) continue;
      if (printedLegend) _separator(bytes, width);
      _bold(bytes, legend.bold);
      _wrappedLine(bytes, legend.text, width);
      _bold(bytes, false);
      printedLegend = true;
    }
    if (printedLegend) {
      bytes.add([0x1B, 0x64, 0x02]);
    } else {
      bytes.add([0x1B, 0x64, 0x03]);
    }
    if (settings.openCashDrawer) bytes.add([0x1B, 0x70, 0x00, 0x19, 0xFA]);
    if (settings.cutPaper) bytes.add([0x1D, 0x56, 0x01]);
    return bytes.toBytes();
  }

  Future<Uint8List> _buildReceipt(
    SaleReceipt receipt,
    PrinterSettings settings,
  ) async {
    final bytes = BytesBuilder();
    final width = settings.paperWidthMm == 58 ? 32 : 42;
    bytes.add([0x1B, 0x40, 0x1B, 0x74, 0x10, 0x1B, 0x4D, 0x00]);
    if (settings.includeLogo) {
      try {
        final logo = settings.logoBase64.isNotEmpty
            ? base64Decode(settings.logoBase64)
            : (await rootBundle.load(
                'assets/icon/app_icon.png',
              )).buffer.asUint8List();
        bytes.add(_rasterLogo(logo, settings.paperWidthMm));
        bytes.add([0x1B, 0x64, 0x01]);
      } catch (_) {
        // El encabezado de texto se conserva si el recurso no puede decodificarse.
      }
    }
    _center(bytes);
    _bold(bytes, true);
    bytes.add([0x1D, 0x21, 0x11]);
    _line(
      bytes,
      settings.businessName.trim().isEmpty
          ? 'KOMMERZE'
          : settings.businessName.toUpperCase(),
    );
    bytes.add([0x1D, 0x21, 0x00]);
    _bold(bytes, false);
    if (settings.showBranchName && receipt.branchName.trim().isNotEmpty) {
      _wrappedLine(bytes, receipt.branchName, width);
    }
    if (settings.showBranchAddress && receipt.branchAddress.trim().isNotEmpty) {
      _wrappedLine(bytes, receipt.branchAddress, width);
    }
    if (settings.showBranchPhone && receipt.branchPhone.trim().isNotEmpty) {
      _wrappedLine(bytes, receipt.branchPhone, width);
    }
    if (settings.showBranchEmail && receipt.branchEmail.trim().isNotEmpty) {
      _wrappedLine(bytes, receipt.branchEmail, width);
    }
    bytes.add([0x1B, 0x4A, 0x0F]);
    _separator(bytes, width);
    bytes.add(_safe('Folio: '));
    _bold(bytes, true);
    _line(bytes, receipt.order.folio.toString());
    _bold(bytes, false);
    _wrappedLine(bytes, 'Fecha: ${_date(receipt.order.date)}', width);
    _wrappedLine(bytes, 'Cajero: ${receipt.cashierName}', width);
    _wrappedLine(bytes, 'Cliente: ${receipt.client.name}', width);
    _separator(bytes, width);
    _linePair(bytes, 'Descripción', 'Importe', width);
    for (var index = 0; index < receipt.items.length; index++) {
      final item = receipt.items[index];
      _left(bytes);
      bytes.add([0x1B, 0x4D, 0x01]);
      _bold(bytes, true);
      _wrappedIndentedLine(
        bytes,
        item.product.displayName.toUpperCase(),
        width,
        settings.paperWidthMm == 58 ? '' : '    ',
      );
      _bold(bytes, false);
      bytes.add([0x1B, 0x4D, 0x00]);
      _center(bytes);
      _linePair(
        bytes,
        '${item.quantity.toStringAsFixed(2)} x ${_money(item.unitPrice)}',
        _money(item.total),
        width,
      );
      if (index < receipt.items.length - 1) bytes.add([0x1B, 0x4A, 0x02]);
    }
    _separator(bytes, width);
    _linePair(bytes, 'Subtotal:', _money(receipt.subtotal), width);
    _linePair(bytes, 'Descuento:', _money(receipt.discount), width);
    _bold(bytes, true);
    bytes.add([0x1D, 0x21, 0x01]);
    _linePair(bytes, 'TOTAL:', _money(receipt.total), width);
    bytes.add([0x1D, 0x21, 0x00]);
    _bold(bytes, false);
    _line(bytes, '');
    _linePair(bytes, 'Pago:', _money(receipt.paid), width);
    _linePair(
      bytes,
      'Cambio:',
      _money((receipt.paid - receipt.total).clamp(0, double.infinity)),
      width,
    );
    _separator(bytes, width);
    _center(bytes);
    var printedLegend = false;
    for (var index = 0; index < settings.legends.length; index++) {
      final legend = settings.legends[index];
      if (legend.text.trim().isEmpty) continue;
      if (printedLegend) _separator(bytes, width);
      _bold(bytes, legend.bold);
      _wrappedLine(bytes, legend.text, width);
      _bold(bytes, false);
      printedLegend = true;
    }
    if (printedLegend) {
      bytes.add([0x1B, 0x64, 0x02]);
    } else {
      bytes.add([0x1B, 0x64, 0x03]);
    }
    if (settings.openCashDrawer) bytes.add([0x1B, 0x70, 0x00, 0x19, 0xFA]);
    if (settings.cutPaper) bytes.add([0x1D, 0x56, 0x01]);
    return bytes.toBytes();
  }

  List<int> _rasterLogo(Uint8List source, int paperWidthMm) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return const [];
    final maxWidth = paperWidthMm == 58 ? 230 : 340;
    final ratio = decoded.width / decoded.height;
    var targetWidth = maxWidth;
    var targetHeight = (targetWidth / ratio).round();
    final maxHeight = paperWidthMm == 58 ? 120 : 150;
    if (targetHeight > maxHeight) {
      targetHeight = maxHeight;
      targetWidth = (targetHeight * ratio).round();
    }
    final resized = img.copyResize(
      decoded,
      width: targetWidth,
      height: targetHeight,
    );
    final widthBytes = (resized.width + 7) ~/ 8;
    final data = BytesBuilder();
    _center(data);
    data.add([
      0x1D,
      0x76,
      0x30,
      0x00,
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      resized.height & 0xFF,
      (resized.height >> 8) & 0xFF,
    ]);
    for (var y = 0; y < resized.height; y++) {
      for (var xByte = 0; xByte < widthBytes; xByte++) {
        var value = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = xByte * 8 + bit;
          if (x >= resized.width) continue;
          final pixel = resized.getPixel(x, y);
          final luminance =
              (pixel.r * .299) + (pixel.g * .587) + (pixel.b * .114);
          if (pixel.a > 40 && luminance < 155) value |= 1 << (7 - bit);
        }
        data.addByte(value);
      }
    }
    data.addByte(0x0A);
    return data.toBytes();
  }

  void _line(BytesBuilder bytes, String value) {
    bytes.add(_safe(value));
    bytes.addByte(0x0A);
  }

  void _separator(BytesBuilder bytes, int width) => _line(bytes, '-' * width);
  void _linePair(BytesBuilder bytes, String left, String right, int width) {
    final maxLeft = (width - right.length - 1).clamp(1, width);
    final safeLeft = left.length > maxLeft ? left.substring(0, maxLeft) : left;
    final spaces = (width - safeLeft.length - right.length).clamp(1, width);
    _line(bytes, '$safeLeft${' ' * spaces}$right');
  }

  void _wrappedLine(BytesBuilder bytes, String value, int width) {
    final paragraphs = value
        .replaceAll(r'\n', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u2028', '\n')
        .replaceAll('\u2029', '\n')
        .split('\n');
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        _line(bytes, '');
        continue;
      }
      final words = paragraph.trim().split(RegExp(r'[ \t]+'));
      var line = '';
      for (final word in words) {
        if (line.isNotEmpty && line.length + word.length + 1 > width) {
          _line(bytes, line);
          line = word;
        } else {
          line = line.isEmpty ? word : '$line $word';
        }
      }
      if (line.isNotEmpty) _line(bytes, line);
    }
  }

  void _wrappedIndentedLine(
    BytesBuilder bytes,
    String value,
    int width,
    String indent,
  ) {
    final contentWidth = (width - indent.length).clamp(1, width);
    final paragraphs = value
        .replaceAll(r'\n', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u2028', '\n')
        .replaceAll('\u2029', '\n')
        .split('\n');
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        _line(bytes, '');
        continue;
      }
      final words = paragraph.trim().split(RegExp(r'[ \t]+'));
      var line = '';
      for (final word in words) {
        if (line.isNotEmpty && line.length + word.length + 1 > contentWidth) {
          _line(bytes, '$indent$line');
          line = word;
        } else {
          line = line.isEmpty ? word : '$line $word';
        }
      }
      if (line.isNotEmpty) _line(bytes, '$indent$line');
    }
  }

  List<int> _safe(String value) =>
      value.codeUnits.map((code) => code <= 255 ? code : 0x3F).toList();

  void _center(BytesBuilder bytes) => bytes.add([0x1B, 0x61, 0x01]);
  void _left(BytesBuilder bytes) => bytes.add([0x1B, 0x61, 0x00]);
  void _bold(BytesBuilder bytes, bool enabled) =>
      bytes.add([0x1B, 0x45, enabled ? 0x01 : 0x00]);
  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class PrinterException implements Exception {
  final String message;
  const PrinterException(this.message);
  @override
  String toString() => message;
}
