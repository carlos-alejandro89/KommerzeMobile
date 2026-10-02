class PrinterSettings {
  final String ipAddress;
  final int port;
  final bool cutPaper;
  final bool openCashDrawer;
  final bool includeLogo;
  final bool printAfterSale;
  final String smtpServer;
  final int smtpPort;
  final String smtpUsername;
  final String senderEmail;
  final String senderName;
  final SmtpSecurity smtpSecurity;
  final String businessName;
  final bool showBranchName;
  final bool showBranchAddress;
  final bool showBranchPhone;
  final bool showBranchEmail;
  final int paperWidthMm;
  final String logoBase64;
  final List<ReceiptLegend> legends;

  const PrinterSettings({
    this.ipAddress = '',
    this.port = 9100,
    this.cutPaper = true,
    this.openCashDrawer = false,
    this.includeLogo = true,
    this.printAfterSale = false,
    this.smtpServer = '',
    this.smtpPort = 587,
    this.smtpUsername = '',
    this.senderEmail = '',
    this.senderName = 'Kommerze',
    this.smtpSecurity = SmtpSecurity.startTls,
    this.businessName = 'KOMMERZE',
    this.showBranchName = true,
    this.showBranchAddress = false,
    this.showBranchPhone = false,
    this.showBranchEmail = false,
    this.paperWidthMm = 80,
    this.logoBase64 = '',
    this.legends = const [],
  });

  bool get isConfigured => ipAddress.trim().isNotEmpty && port > 0;
  bool get isEmailConfigured =>
      smtpServer.trim().isNotEmpty &&
      smtpPort > 0 &&
      smtpUsername.trim().isNotEmpty &&
      senderEmail.trim().isNotEmpty;

  PrinterSettings copyWith({
    String? ipAddress,
    int? port,
    bool? cutPaper,
    bool? openCashDrawer,
    bool? includeLogo,
    bool? printAfterSale,
    String? smtpServer,
    int? smtpPort,
    String? smtpUsername,
    String? senderEmail,
    String? senderName,
    SmtpSecurity? smtpSecurity,
    String? businessName,
    bool? showBranchName,
    bool? showBranchAddress,
    bool? showBranchPhone,
    bool? showBranchEmail,
    int? paperWidthMm,
    String? logoBase64,
    List<ReceiptLegend>? legends,
  }) => PrinterSettings(
    ipAddress: ipAddress ?? this.ipAddress,
    port: port ?? this.port,
    cutPaper: cutPaper ?? this.cutPaper,
    openCashDrawer: openCashDrawer ?? this.openCashDrawer,
    includeLogo: includeLogo ?? this.includeLogo,
    printAfterSale: printAfterSale ?? this.printAfterSale,
    smtpServer: smtpServer ?? this.smtpServer,
    smtpPort: smtpPort ?? this.smtpPort,
    smtpUsername: smtpUsername ?? this.smtpUsername,
    senderEmail: senderEmail ?? this.senderEmail,
    senderName: senderName ?? this.senderName,
    smtpSecurity: smtpSecurity ?? this.smtpSecurity,
    businessName: businessName ?? this.businessName,
    showBranchName: showBranchName ?? this.showBranchName,
    showBranchAddress: showBranchAddress ?? this.showBranchAddress,
    showBranchPhone: showBranchPhone ?? this.showBranchPhone,
    showBranchEmail: showBranchEmail ?? this.showBranchEmail,
    paperWidthMm: paperWidthMm ?? this.paperWidthMm,
    logoBase64: logoBase64 ?? this.logoBase64,
    legends: legends ?? this.legends,
  );
}

class ReceiptLegend {
  final String text;
  final bool bold;
  const ReceiptLegend({required this.text, this.bold = false});

  Map<String, Object> toJson() => {'text': text, 'bold': bold};
  factory ReceiptLegend.fromJson(Map<String, Object?> json) => ReceiptLegend(
    text: json['text']?.toString() ?? '',
    bold: json['bold'] == true,
  );
}

enum SmtpSecurity { startTls, sslTls, none }

extension SmtpSecurityInfo on SmtpSecurity {
  String get label => switch (this) {
    SmtpSecurity.startTls => 'STARTTLS',
    SmtpSecurity.sslTls => 'SSL/TLS',
    SmtpSecurity.none => 'Sin cifrado',
  };
}
