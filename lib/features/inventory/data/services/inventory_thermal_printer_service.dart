import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:kommerze_mobile/features/printer/data/services/thermal_printer_service.dart';
import 'package:kommerze_mobile/features/printer/domain/entities/printer_settings.dart';

class InventoryThermalPrinterService {
  const InventoryThermalPrinterService();

  Future<void> printInventory(
    List<InventoryItem> items,
    PrinterSettings settings, {
    required String scopeLabel,
    String branchName = '',
    String branchAddress = '',
    String branchPhone = '',
    String branchEmail = '',
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
        await _buildReceipt(
          items,
          settings,
          scopeLabel,
          branchName: branchName,
          branchAddress: branchAddress,
          branchPhone: branchPhone,
          branchEmail: branchEmail,
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

  Future<Uint8List> _buildReceipt(
    List<InventoryItem> items,
    PrinterSettings settings,
    String scopeLabel, {
    required String branchName,
    required String branchAddress,
    required String branchPhone,
    required String branchEmail,
  }) async {
    final bytes = BytesBuilder();
    final isNarrow = settings.paperWidthMm == 58;
    final width = isNarrow ? 29 : 38;
    final leftMarginDots = isNarrow ? 16 : 24;
    final printAreaDots = isNarrow ? 352 : 528;
    bytes.add([0x1B, 0x40, 0x1B, 0x74, 0x10, 0x1B, 0x4D, 0x00]);
    bytes.add([
      0x1D,
      0x4C,
      leftMarginDots & 0xFF,
      (leftMarginDots >> 8) & 0xFF,
    ]);
    bytes.add([0x1D, 0x57, printAreaDots & 0xFF, (printAreaDots >> 8) & 0xFF]);
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
    _line(
      bytes,
      settings.businessName.trim().isEmpty
          ? 'KOMMERZE'
          : settings.businessName.toUpperCase(),
    );
    if (settings.showBranchName && branchName.trim().isNotEmpty) {
      _wrappedLine(bytes, branchName, width);
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
    _line(bytes, 'INVENTARIO');
    _bold(bytes, false);
    _wrappedLine(bytes, scopeLabel.toUpperCase(), width);
    _line(bytes, _date(DateTime.now()));
    _separator(bytes, width);
    _left(bytes);

    final sortedItems = [...items]
      ..sort((first, second) {
        final lineComparison = _lineName(
          first,
        ).toLowerCase().compareTo(_lineName(second).toLowerCase());
        return lineComparison != 0
            ? lineComparison
            : first.displayName.toLowerCase().compareTo(
                second.displayName.toLowerCase(),
              );
      });
    String? currentLine;
    for (final item in sortedItems) {
      final line = _lineName(item);
      if (line != currentLine) {
        if (currentLine != null) _line(bytes, '');
        _center(bytes);
        _bold(bytes, true);
        _wrappedLine(bytes, 'LINEA: ${line.toUpperCase()}', width);
        _bold(bytes, false);
        _separator(bytes, width);
        _left(bytes);
        currentLine = line;
      }
      _bold(bytes, true);
      _wrappedLine(bytes, item.displayName, width);
      _bold(bytes, false);
      _linePair(
        bytes,
        'Exist: ${_quantity(item.stock)}',
        'Compra: ${_money(item.purchasePrice)}',
        width,
      );
      _line(bytes, '');
    }

    _separator(bytes, width);
    _bold(bytes, true);
    _linePair(bytes, 'Articulos:', items.length.toString(), width);
    _linePair(
      bytes,
      'Valor compra:',
      _money(
        items.fold(0, (total, item) => total + item.stock * item.purchasePrice),
      ),
      width,
    );
    _bold(bytes, false);
    bytes.add([0x1B, 0x64, 0x03]);
    if (settings.cutPaper) bytes.add([0x1D, 0x56, 0x01]);
    return bytes.toBytes();
  }

  List<int> _rasterLogo(Uint8List source, int paperWidthMm) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return const [];
    final maxWidth = paperWidthMm == 58 ? 210 : 300;
    final ratio = decoded.width / decoded.height;
    var targetWidth = maxWidth;
    var targetHeight = (targetWidth / ratio).round();
    final maxHeight = paperWidthMm == 58 ? 110 : 140;
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
    final contentWidth = (width - 2).clamp(1, width);
    final maxLeft = (contentWidth - right.length - 1).clamp(1, contentWidth);
    final safeLeft = left.length > maxLeft ? left.substring(0, maxLeft) : left;
    final spaces = (contentWidth - safeLeft.length - right.length).clamp(
      1,
      contentWidth,
    );
    _line(bytes, ' $safeLeft${' ' * spaces}$right ');
  }

  void _wrappedLine(BytesBuilder bytes, String value, int width) {
    final words = value.trim().split(RegExp(r'\s+'));
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

  List<int> _safe(String value) =>
      value.codeUnits.map((code) => code <= 255 ? code : 0x3F).toList();

  void _center(BytesBuilder bytes) => bytes.add([0x1B, 0x61, 0x01]);
  void _left(BytesBuilder bytes) => bytes.add([0x1B, 0x61, 0x00]);
  void _bold(BytesBuilder bytes, bool enabled) =>
      bytes.add([0x1B, 0x45, enabled ? 0x01 : 0x00]);

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
  String _lineName(InventoryItem item) {
    final value = item.lineName.trim();
    return value.isEmpty ? 'SIN LÍNEA' : value;
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
