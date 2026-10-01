import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:kommerze_mobile/features/checkout/domain/entities/sale_payment.dart';
import 'package:kommerze_mobile/features/printer/domain/entities/printer_settings.dart';
import 'package:kommerze_mobile/features/printer/domain/entities/sale_receipt.dart';

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

  Future<Uint8List> _buildReceipt(
    SaleReceipt receipt,
    PrinterSettings settings,
  ) async {
    final bytes = BytesBuilder();
    bytes.add([0x1B, 0x40]);
    bytes.add([0x1B, 0x74, 0x12]);
    if (settings.openCashDrawer) bytes.add([0x1B, 0x70, 0x00, 0x32, 0xFA]);
    if (settings.includeLogo) {
      try {
        final logo = await rootBundle.load('assets/icon/app_icon.png');
        bytes.add(_rasterLogo(logo.buffer.asUint8List()));
      } catch (_) {
        // El encabezado de texto se conserva si el recurso no puede decodificarse.
      }
    }
    _center(bytes);
    _bold(bytes, true);
    _line(bytes, 'KOMMERZE');
    _bold(bytes, false);
    _line(bytes, 'RECIBO DE VENTA');
    _line(bytes, 'Folio: ${receipt.folio}');
    _line(bytes, _date(receipt.order.date));
    _separator(bytes);
    _left(bytes);
    _line(bytes, 'Cliente: ${receipt.client.name}');
    if (receipt.client.email.trim().isNotEmpty) {
      _line(bytes, 'Correo: ${receipt.client.email.trim()}');
    }
    _separator(bytes);
    for (final item in receipt.items) {
      _bold(bytes, true);
      _line(bytes, item.product.displayName);
      _bold(bytes, false);
      _line(
        bytes,
        '${_quantity(item.quantity)} x ${_money(item.unitPrice)}  ${_money(item.total)}',
      );
    }
    _separator(bytes);
    _amount(bytes, 'Subtotal', receipt.subtotal);
    if (receipt.discount > 0) _amount(bytes, 'Descuento', -receipt.discount);
    _bold(bytes, true);
    _amount(bytes, 'TOTAL', receipt.total);
    _bold(bytes, false);
    _separator(bytes);
    for (final payment in receipt.payments) {
      _amount(bytes, payment.method.label, payment.amount);
    }
    _amount(bytes, 'Pagado', receipt.paid);
    _center(bytes);
    _line(bytes, 'GRACIAS POR SU COMPRA');
    _line(bytes, 'Kommerze - Vende, gestiona y crece');
    bytes.add([0x0A, 0x0A, 0x0A]);
    if (settings.cutPaper) bytes.add([0x1D, 0x56, 0x41, 0x03]);
    return bytes.toBytes();
  }

  List<int> _rasterLogo(Uint8List source) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return const [];
    final resized = img.copyResize(decoded, width: 192);
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

  void _separator(BytesBuilder bytes) => _line(bytes, '-' * 42);
  void _amount(BytesBuilder bytes, String label, double amount) {
    final value = _money(amount);
    final spaces = (42 - label.length - value.length).clamp(1, 42);
    _line(bytes, '$label${' ' * spaces}$value');
  }

  List<int> _safe(String value) => value
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ñ', 'N')
      .codeUnits
      .map((code) => code <= 255 ? code : 0x3F)
      .toList();

  void _center(BytesBuilder bytes) => bytes.add([0x1B, 0x61, 0x01]);
  void _left(BytesBuilder bytes) => bytes.add([0x1B, 0x61, 0x00]);
  void _bold(BytesBuilder bytes, bool enabled) =>
      bytes.add([0x1B, 0x45, enabled ? 0x01 : 0x00]);
  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
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
