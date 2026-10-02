import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
  late final TextEditingController _businessName;
  late bool _cutPaper;
  late bool _openDrawer;
  late bool _includeLogo;
  late bool _printAfterSale;
  late SmtpSecurity _smtpSecurity;
  late bool _showBranchName;
  late bool _showBranchAddress;
  late bool _showBranchPhone;
  late bool _showBranchEmail;
  late int _paperWidthMm;
  late String _logoBase64;
  late List<_LegendDraft> _legends;
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
    _businessName = TextEditingController(text: settings.businessName);
    _cutPaper = settings.cutPaper;
    _openDrawer = settings.openCashDrawer;
    _includeLogo = settings.includeLogo;
    _printAfterSale = settings.printAfterSale;
    _smtpSecurity = settings.smtpSecurity;
    _showBranchName = settings.showBranchName;
    _showBranchAddress = settings.showBranchAddress;
    _showBranchPhone = settings.showBranchPhone;
    _showBranchEmail = settings.showBranchEmail;
    _paperWidthMm = settings.paperWidthMm;
    _logoBase64 = settings.logoBase64;
    _legends = settings.legends
        .map(
          (legend) => _LegendDraft(
            controller: TextEditingController(text: legend.text),
            bold: legend.bold,
          ),
        )
        .toList();
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
    _businessName.dispose();
    for (final legend in _legends) {
      legend.controller.dispose();
    }
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                    children: [
                      _Card(
                        title: 'Formato del ticket',
                        icon: Icons.receipt_long_outlined,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _businessName,
                              decoration: const InputDecoration(
                                labelText: 'Nombre comercial',
                                hintText: 'KOMMERZE',
                                prefixIcon: Icon(Icons.storefront_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              initialValue: _paperWidthMm,
                              decoration: const InputDecoration(
                                labelText: 'Ancho del papel',
                                prefixIcon: Icon(Icons.straighten_rounded),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 80,
                                  child: Text('80 mm · 42 columnas'),
                                ),
                                DropdownMenuItem(
                                  value: 58,
                                  child: Text('58 mm · 32 columnas'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) _paperWidthMm = value;
                              },
                            ),
                            const SizedBox(height: 12),
                            _Option(
                              title: 'Logotipo',
                              subtitle: 'Mostrar el logotipo en el encabezado',
                              value: _includeLogo,
                              onChanged: (value) =>
                                  setState(() => _includeLogo = value),
                            ),
                            if (_includeLogo) _logoSelector(),
                            _Option(
                              title: 'Nombre de sucursal',
                              subtitle: 'Nombre registrado de la sucursal',
                              value: _showBranchName,
                              onChanged: (value) =>
                                  setState(() => _showBranchName = value),
                            ),
                            _Option(
                              title: 'Dirección',
                              subtitle: 'Domicilio registrado de la sucursal',
                              value: _showBranchAddress,
                              onChanged: (value) =>
                                  setState(() => _showBranchAddress = value),
                            ),
                            _Option(
                              title: 'Teléfono',
                              subtitle: 'Teléfono principal de la sucursal',
                              value: _showBranchPhone,
                              onChanged: (value) =>
                                  setState(() => _showBranchPhone = value),
                            ),
                            _Option(
                              title: 'Correo electrónico',
                              subtitle: 'Correo registrado de la sucursal',
                              value: _showBranchEmail,
                              onChanged: (value) =>
                                  setState(() => _showBranchEmail = value),
                            ),
                            const Divider(height: 30),
                            Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Grupos de leyendas',
                                        style: TextStyle(
                                          color: AppColors.navy,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Cada grupo se separa con una línea.',
                                        style: TextStyle(
                                          color: AppColors.textGrey,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _addLegend,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Agregar'),
                                ),
                              ],
                            ),
                            if (_legends.isEmpty)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Text(
                                  'No hay leyendas configuradas.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textGrey),
                                ),
                              ),
                            for (
                              var index = 0;
                              index < _legends.length;
                              index++
                            )
                              _legendEditor(index),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
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
                                prefixIcon: Icon(
                                  Icons.settings_ethernet_rounded,
                                ),
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
                            Icon(
                              Icons.info_outline,
                              color: AppColors.primaryBlue,
                            ),
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
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
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
        businessName: _businessName.text,
        showBranchName: _showBranchName,
        showBranchAddress: _showBranchAddress,
        showBranchPhone: _showBranchPhone,
        showBranchEmail: _showBranchEmail,
        paperWidthMm: _paperWidthMm,
        logoBase64: _logoBase64,
        legends: _legends
            .map(
              (legend) => ReceiptLegend(
                text: legend.controller.text.trim(),
                bold: legend.bold,
              ),
            )
            .where((legend) => legend.text.isNotEmpty)
            .toList(growable: false),
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

  Widget _logoSelector() {
    Uint8List? bytes;
    try {
      if (_logoBase64.isNotEmpty) bytes = base64Decode(_logoBase64);
    } catch (_) {}
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 108,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderGrey),
            ),
            child: bytes == null
                ? const Icon(Icons.image_outlined, color: AppColors.textGrey)
                : Image.memory(bytes, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _chooseLogo,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(bytes == null ? 'Elegir logotipo' : 'Cambiar'),
                ),
                if (bytes != null)
                  TextButton(
                    onPressed: () => setState(() => _logoBase64 = ''),
                    child: const Text('Usar logo de Kommerze'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendEditor(int index) {
    final legend = _legends[index];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Leyenda ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton.filledTonal(
                tooltip: legend.bold ? 'Quitar negritas' : 'Usar negritas',
                onPressed: () => setState(() => legend.bold = !legend.bold),
                icon: Icon(
                  Icons.format_bold_rounded,
                  color: legend.bold ? AppColors.primaryBlue : null,
                ),
              ),
              IconButton(
                tooltip: 'Eliminar leyenda',
                onPressed: () => _removeLegend(index),
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
            ],
          ),
          TextField(
            controller: legend.controller,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 2,
            maxLines: 4,
            style: TextStyle(
              fontWeight: legend.bold ? FontWeight.bold : FontWeight.normal,
            ),
            decoration: const InputDecoration(
              hintText: 'Escribe el contenido de esta leyenda...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      allowMultiple: false,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || !mounted) return;
    if (bytes.length > 2 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El logotipo no debe exceder 2 MB.')),
      );
      return;
    }
    setState(() => _logoBase64 = base64Encode(bytes));
  }

  void _addLegend() => setState(
    () => _legends.add(
      _LegendDraft(controller: TextEditingController(), bold: false),
    ),
  );

  void _removeLegend(int index) {
    final removed = _legends.removeAt(index);
    removed.controller.dispose();
    setState(() {});
  }
}

class _LegendDraft {
  final TextEditingController controller;
  bool bold;
  _LegendDraft({required this.controller, required this.bold});
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
