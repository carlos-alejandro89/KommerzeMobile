import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:kommerze_mobile/core/storage/shared_prefs_provider.dart';
import 'package:kommerze_mobile/core/storage/secure_storage_provider.dart';
import 'package:kommerze_mobile/features/printer/domain/entities/printer_settings.dart';

class PrinterSettingsController extends Notifier<PrinterSettings> {
  static const _ipKey = 'printer_ip';
  static const _portKey = 'printer_port';
  static const _cutKey = 'printer_cut_paper';
  static const _drawerKey = 'printer_open_drawer';
  static const _logoKey = 'printer_include_logo';
  static const _automaticKey = 'printer_after_sale';
  static const _smtpServerKey = 'smtp_server';
  static const _smtpPortKey = 'smtp_port';
  static const _smtpUsernameKey = 'smtp_username';
  static const _senderEmailKey = 'smtp_sender_email';
  static const _senderNameKey = 'smtp_sender_name';
  static const _smtpSecurityKey = 'smtp_security';
  static const smtpPasswordKey = 'smtp_password';
  static const _businessNameKey = 'receipt_business_name';
  static const _showBranchNameKey = 'receipt_show_branch_name';
  static const _showBranchAddressKey = 'receipt_show_branch_address';
  static const _showBranchPhoneKey = 'receipt_show_branch_phone';
  static const _showBranchEmailKey = 'receipt_show_branch_email';
  static const _paperWidthKey = 'receipt_paper_width';
  static const _logoKeyCustom = 'receipt_logo_base64';
  static const _legendsKey = 'receipt_legend_groups';

  @override
  PrinterSettings build() {
    final preferences = ref.read(sharedPrefsProvider);
    return PrinterSettings(
      ipAddress: preferences.getString(_ipKey) ?? '',
      port: preferences.getInt(_portKey) ?? 9100,
      cutPaper: preferences.getBool(_cutKey) ?? true,
      openCashDrawer: preferences.getBool(_drawerKey) ?? false,
      includeLogo: preferences.getBool(_logoKey) ?? true,
      printAfterSale: preferences.getBool(_automaticKey) ?? false,
      smtpServer: preferences.getString(_smtpServerKey) ?? '',
      smtpPort: preferences.getInt(_smtpPortKey) ?? 587,
      smtpUsername: preferences.getString(_smtpUsernameKey) ?? '',
      senderEmail: preferences.getString(_senderEmailKey) ?? '',
      senderName: preferences.getString(_senderNameKey) ?? 'Kommerze',
      smtpSecurity: SmtpSecurity.values.firstWhere(
        (value) => value.name == preferences.getString(_smtpSecurityKey),
        orElse: () => SmtpSecurity.startTls,
      ),
      businessName: preferences.getString(_businessNameKey) ?? 'KOMMERZE',
      showBranchName: preferences.getBool(_showBranchNameKey) ?? true,
      showBranchAddress: preferences.getBool(_showBranchAddressKey) ?? false,
      showBranchPhone: preferences.getBool(_showBranchPhoneKey) ?? false,
      showBranchEmail: preferences.getBool(_showBranchEmailKey) ?? false,
      paperWidthMm: preferences.getInt(_paperWidthKey) == 58 ? 58 : 80,
      logoBase64: preferences.getString(_logoKeyCustom) ?? '',
      legends: _decodeLegends(preferences.getString(_legendsKey)),
    );
  }

  Future<void> save(PrinterSettings settings) async {
    final preferences = ref.read(sharedPrefsProvider);
    await Future.wait([
      preferences.setString(_ipKey, settings.ipAddress.trim()),
      preferences.setInt(_portKey, settings.port),
      preferences.setBool(_cutKey, settings.cutPaper),
      preferences.setBool(_drawerKey, settings.openCashDrawer),
      preferences.setBool(_logoKey, settings.includeLogo),
      preferences.setBool(_automaticKey, settings.printAfterSale),
      preferences.setString(_smtpServerKey, settings.smtpServer.trim()),
      preferences.setInt(_smtpPortKey, settings.smtpPort),
      preferences.setString(_smtpUsernameKey, settings.smtpUsername.trim()),
      preferences.setString(_senderEmailKey, settings.senderEmail.trim()),
      preferences.setString(_senderNameKey, settings.senderName.trim()),
      preferences.setString(_smtpSecurityKey, settings.smtpSecurity.name),
      preferences.setString(_businessNameKey, settings.businessName.trim()),
      preferences.setBool(_showBranchNameKey, settings.showBranchName),
      preferences.setBool(_showBranchAddressKey, settings.showBranchAddress),
      preferences.setBool(_showBranchPhoneKey, settings.showBranchPhone),
      preferences.setBool(_showBranchEmailKey, settings.showBranchEmail),
      preferences.setInt(_paperWidthKey, settings.paperWidthMm),
      preferences.setString(_logoKeyCustom, settings.logoBase64),
      preferences.setString(
        _legendsKey,
        jsonEncode(settings.legends.map((legend) => legend.toJson()).toList()),
      ),
    ]);
    state = settings.copyWith(
      ipAddress: settings.ipAddress.trim(),
      smtpServer: settings.smtpServer.trim(),
      smtpUsername: settings.smtpUsername.trim(),
      senderEmail: settings.senderEmail.trim(),
      senderName: settings.senderName.trim(),
      businessName: settings.businessName.trim(),
    );
  }

  Future<String> readEmailPassword() async =>
      await ref.read(secureStorageProvider).read(key: smtpPasswordKey) ?? '';

  Future<void> saveEmailPassword(String password) => ref
      .read(secureStorageProvider)
      .write(key: smtpPasswordKey, value: password);

  static List<ReceiptLegend> _decodeLegends(String? value) {
    if (value == null || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ReceiptLegend.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

final printerSettingsControllerProvider =
    NotifierProvider<PrinterSettingsController, PrinterSettings>(
      PrinterSettingsController.new,
    );
