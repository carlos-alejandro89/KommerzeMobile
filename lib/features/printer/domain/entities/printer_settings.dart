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
