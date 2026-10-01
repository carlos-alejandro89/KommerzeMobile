import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/printer/domain/entities/printer_settings.dart';
import 'package:kommerze_mobile/features/printer/presentation/controllers/printer_settings_controller.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ip;
  late final TextEditingController _port;
  late final TextEditingController _smtpServer;
  late final TextEditingController _smtpPort;
  late final TextEditingController _smtpUsername;
  late final TextEditingController _smtpPassword;
  late final TextEditingController _senderEmail;
  late final TextEditingController _senderName;
  late bool _cutPaper;
  late bool _openDrawer;
  late bool _includeLogo;
  late bool _printAfterSale;
  late SmtpSecurity _smtpSecurity;
  bool _hidePassword = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(printerSettingsControllerProvider);
    _ip = TextEditingController(text: settings.ipAddress);
    _port = TextEditingController(text: settings.port.toString());
    _smtpServer = TextEditingController(text: settings.smtpServer);
    _smtpPort = TextEditingController(text: settings.smtpPort.toString());
    _smtpUsername = TextEditingController(text: settings.smtpUsername);
    _smtpPassword = TextEditingController();
    _senderEmail = TextEditingController(text: settings.senderEmail);
    _senderName = TextEditingController(text: settings.senderName);
    _cutPaper = settings.cutPaper;
    _openDrawer = settings.openCashDrawer;
    _includeLogo = settings.includeLogo;
    _printAfterSale = settings.printAfterSale;
    _smtpSecurity = settings.smtpSecurity;
    Future.microtask(_loadPassword);
  }

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    _smtpServer.dispose();
    _smtpPort.dispose();
    _smtpUsername.dispose();
    _smtpPassword.dispose();
    _senderEmail.dispose();
    _senderName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          const AppHeader(
            title: 'Recibos',
            subtitle: 'Configura impresión y envío por correo',
            height: 106,
            showBackButton: true,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                children: [
                  _Card(
                    title: 'Conexión de red',
                    icon: Icons.router_outlined,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _ip,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Dirección IP',
                            hintText: '192.168.1.100',
                            prefixIcon: Icon(Icons.lan_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateIp,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _port,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Puerto',
                            hintText: '9100',
                            prefixIcon: Icon(Icons.settings_ethernet_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: _validatePort,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Card(
                    title: 'Servidor de correo',
                    icon: Icons.outgoing_mail,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _smtpServer,
                          decoration: const InputDecoration(
                            labelText: 'Servidor SMTP',
                            hintText: 'smtp.tudominio.com',
                            prefixIcon: Icon(Icons.dns_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _smtpPort,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Puerto',
                                  hintText: '587',
                                  border: OutlineInputBorder(),
                                ),
                                validator: _validatePort,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<SmtpSecurity>(
                                initialValue: _smtpSecurity,
                                decoration: const InputDecoration(
                                  labelText: 'Seguridad',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final value in SmtpSecurity.values)
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) _smtpSecurity = value;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _smtpUsername,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Usuario SMTP',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _smtpPassword,
                          obscureText: _hidePassword,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.password_outlined),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _senderEmail,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo remitente',
                            hintText: 'ventas@tudominio.com',
                            prefixIcon: Icon(Icons.alternate_email),
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _senderName,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del remitente',
                            hintText: 'Kommerze',
                            prefixIcon: Icon(Icons.storefront_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'La contraseña se guarda cifrada en el almacenamiento seguro del dispositivo.',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Card(
                    title: 'Opciones del recibo',
                    icon: Icons.receipt_long_outlined,
                    child: Column(
                      children: [
                        _Option(
                          title: 'Incluir logo',
                          subtitle:
                              'Imprime el logo de Kommerze en el encabezado',
                          value: _includeLogo,
                          onChanged: (value) =>
                              setState(() => _includeLogo = value),
                        ),
                        _Option(
                          title: 'Cortar papel',
                          subtitle: 'Envía el comando de corte al terminar',
                          value: _cutPaper,
                          onChanged: (value) =>
                              setState(() => _cutPaper = value),
                        ),
                        _Option(
                          title: 'Abrir cajón de dinero',
                          subtitle: 'Activa el pulso del cajón al imprimir',
                          value: _openDrawer,
                          onChanged: (value) =>
                              setState(() => _openDrawer = value),
                        ),
                        _Option(
                          title: 'Imprimir al finalizar venta',
                          subtitle:
                              'Imprime automáticamente las ventas confirmadas',
                          value: _printAfterSale,
                          onChanged: (value) =>
                              setState(() => _printAfterSale = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primaryBlue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'La miniprinter debe aceptar ESC/POS. El envío de correo se realiza directamente por SMTP y adjunta el recibo en PDF.',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Guardando...' : 'Guardar configuración'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final controller = ref.read(printerSettingsControllerProvider.notifier);
    await controller.save(
      PrinterSettings(
        ipAddress: _ip.text,
        port: int.parse(_port.text),
        cutPaper: _cutPaper,
        openCashDrawer: _openDrawer,
        includeLogo: _includeLogo,
        printAfterSale: _printAfterSale,
        smtpServer: _smtpServer.text,
        smtpPort: int.parse(_smtpPort.text),
        smtpUsername: _smtpUsername.text,
        senderEmail: _senderEmail.text,
        senderName: _senderName.text,
        smtpSecurity: _smtpSecurity,
      ),
    );
    await controller.saveEmailPassword(_smtpPassword.text);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuración de recibos guardada.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _validateIp(String? value) {
    final input = value?.trim() ?? '';
    final parts = input.split('.');
    if (parts.length != 4 ||
        parts.any((part) {
          final number = int.tryParse(part);
          return number == null || number < 0 || number > 255;
        })) {
      return 'Ingresa una dirección IPv4 válida.';
    }
    return null;
  }

  String? _validatePort(String? value) {
    final port = int.tryParse(value?.trim() ?? '');
    if (port == null || port < 1 || port > 65535) {
      return 'Ingresa un puerto entre 1 y 65535.';
    }
    return null;
  }

  Future<void> _loadPassword() async {
    final password = await ref
        .read(printerSettingsControllerProvider.notifier)
        .readEmailPassword();
    if (mounted) _smtpPassword.text = password;
  }

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Este campo es obligatorio.' : null;

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Ingresa un correo válido.';
    }
    return null;
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Card({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.borderGrey.withValues(alpha: .7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryBlue),
            const SizedBox(width: 9),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _Option extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Option({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
    value: value,
    activeTrackColor: AppColors.primaryBlue,
    onChanged: onChanged,
  );
}
