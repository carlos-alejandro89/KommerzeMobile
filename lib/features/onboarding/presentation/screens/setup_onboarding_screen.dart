import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/network/url_builder.dart';
import 'package:kommerze_mobile/core/setup/app_setup_controller.dart';
import 'package:kommerze_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kommerze_mobile/features/printer/domain/entities/printer_settings.dart';
import 'package:kommerze_mobile/features/printer/presentation/controllers/printer_settings_controller.dart';

class SetupOnboardingScreen extends ConsumerStatefulWidget {
  const SetupOnboardingScreen({super.key});

  @override
  ConsumerState<SetupOnboardingScreen> createState() =>
      _SetupOnboardingScreenState();
}

class _SetupOnboardingScreenState extends ConsumerState<SetupOnboardingScreen> {
  final _baseUrl = TextEditingController();
  final _printerIp = TextEditingController();
  final _printerPort = TextEditingController(text: '9100');
  final _smtpServer = TextEditingController();
  final _smtpPort = TextEditingController(text: '587');
  final _smtpUser = TextEditingController();
  final _smtpPassword = TextEditingController();
  final _senderEmail = TextEditingController();
  final _senderName = TextEditingController(text: 'Kommerze');
  var _step = 0;
  var _busy = false;
  var _hidePassword = true;
  var _smtpSecurity = SmtpSecurity.startTls;
  String? _error;

  @override
  void initState() {
    super.initState();
    final setup = ref.read(appSetupControllerProvider);
    final printer = ref.read(printerSettingsControllerProvider);
    _baseUrl.text = setup.baseUrl;
    _printerIp.text = printer.ipAddress;
    _printerPort.text = printer.port.toString();
    _smtpServer.text = printer.smtpServer;
    _smtpPort.text = printer.smtpPort.toString();
    _smtpUser.text = printer.smtpUsername;
    _senderEmail.text = printer.senderEmail;
    _senderName.text = printer.senderName;
    _smtpSecurity = printer.smtpSecurity;
  }

  @override
  void dispose() {
    for (final controller in [
      _baseUrl,
      _printerIp,
      _printerPort,
      _smtpServer,
      _smtpPort,
      _smtpUser,
      _smtpPassword,
      _senderEmail,
      _senderName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/icon/app_icon.png',
                        width: 46,
                        height: 46,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configurar Kommerze',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Prepararemos este dispositivo para comenzar.',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: List.generate(4, (index) {
                      final active = index <= _step;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primaryBlue
                                : AppColors.borderGrey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: switch (_step) {
                            0 => _serverStep(),
                            1 => _printerStep(),
                            2 => _emailStep(),
                            _ => _readyStep(),
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_step == 1 || _step == 2)
                    TextButton(
                      onPressed: _busy ? null : _next,
                      child: const Text('Omitir por ahora'),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _primaryAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _step == 3 ? 'Ir a iniciar sesión' : 'Continuar',
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _serverStep() => _SetupCard(
    icon: Icons.cloud_outlined,
    title: 'Servidor de Kommerze',
    subtitle:
        'Ingresa la dirección proporcionada por tu administrador. Es obligatorio incluir https:// al inicio. Verificaremos el endpoint /pulse antes de continuar.',
    children: [
      TextField(
        controller: _baseUrl,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Dirección del servidor',
          hintText: 'https://api.miempresa.com',
          prefixIcon: Icon(Icons.link_rounded),
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );

  Widget _printerStep() => _SetupCard(
    icon: Icons.print_outlined,
    title: 'Miniprinter',
    subtitle:
        'Configura la impresora ESC/POS de red. También podrás hacerlo después desde tu perfil.',
    children: [
      TextField(
        controller: _printerIp,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Dirección IP',
          hintText: '192.168.1.100',
          prefixIcon: Icon(Icons.router_outlined),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _printerPort,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Puerto',
          hintText: '9100',
          prefixIcon: Icon(Icons.settings_ethernet_rounded),
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );

  Widget _emailStep() => _SetupCard(
    icon: Icons.mail_outline_rounded,
    title: 'Correo electrónico',
    subtitle:
        'Estas credenciales permitirán enviar recibos directamente desde la aplicación.',
    children: [
      TextField(
        controller: _smtpServer,
        decoration: const InputDecoration(
          labelText: 'Servidor SMTP',
          hintText: 'smtp.miempresa.com',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _smtpPort,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Puerto',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<SmtpSecurity>(
              initialValue: _smtpSecurity,
              decoration: const InputDecoration(
                labelText: 'Seguridad',
                border: OutlineInputBorder(),
              ),
              items: SmtpSecurity.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _smtpSecurity = value);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _smtpUser,
        decoration: const InputDecoration(
          labelText: 'Usuario',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _smtpPassword,
        obscureText: _hidePassword,
        decoration: InputDecoration(
          labelText: 'Contraseña',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
            icon: Icon(
              _hidePassword ? Icons.visibility_outlined : Icons.visibility_off,
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _senderEmail,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Correo remitente',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _senderName,
        decoration: const InputDecoration(
          labelText: 'Nombre del remitente',
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );

  Widget _readyStep() => const _SetupCard(
    icon: Icons.check_circle_outline_rounded,
    title: 'Configuración terminada',
    subtitle:
        'El dispositivo está listo. Después de iniciar sesión descargaremos los catálogos necesarios antes de abrir el inicio.',
    children: [
      _ReadyItem(icon: Icons.cloud_done_outlined, text: 'Servidor verificado'),
      _ReadyItem(
        icon: Icons.tune_rounded,
        text: 'Preferencias opcionales guardadas',
      ),
      _ReadyItem(
        icon: Icons.sync_rounded,
        text: 'Sincronización preparada después del Login',
      ),
    ],
  );

  Future<void> _primaryAction() async {
    setState(() => _error = null);
    switch (_step) {
      case 0:
        await _validateServer();
        return;
      case 1:
        await _savePrinter();
        return;
      case 2:
        await _saveEmail();
        return;
      default:
        await ref.read(authControllerProvider.notifier).logout();
        await ref
            .read(appSetupControllerProvider.notifier)
            .completeOnboarding();
        if (mounted) context.go(AppConstants.loginScreenRoute);
        return;
    }
  }

  void _next() => setState(() {
    _error = null;
    _step++;
  });

  Future<void> _validateServer() async {
    final value = AppSetupController.normalizeBaseUrl(_baseUrl.text);
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(
        () =>
            _error = 'Ingresa una dirección válida que comience con https://.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status != null,
        ),
      ).get<dynamic>(UrlBuilder.join(value, ApiConstants.pulsePath));
      if (response.statusCode != 200) {
        throw Exception('El servidor respondió ${response.statusCode}.');
      }
      final body = response.data;
      if (body is! Map ||
          body['success'] != true ||
          body['service'] != 'kommerze-cloud-api' ||
          body['protocolVersion'] != 1 ||
          body['status'] != 'ok') {
        throw Exception(
          'El servidor no corresponde a una instancia compatible de Kommerze.',
        );
      }
      await ref.read(appSetupControllerProvider.notifier).saveBaseUrl(value);
      if (mounted) _next();
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _error = _dioConnectionMessage(error));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _dioConnectionMessage(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout =>
        'El servidor tardó demasiado en responder. Verifica la dirección y la red.',
      DioExceptionType.receiveTimeout =>
        'El servidor aceptó la conexión, pero no respondió a tiempo.',
      DioExceptionType.badCertificate =>
        'El dispositivo rechazó el certificado HTTPS. Debe ser válido para este dominio y tener la cadena completa.',
      DioExceptionType.connectionError =>
        'No fue posible abrir la conexión. Verifica el dominio, el certificado HTTPS y que el servidor sea accesible desde este dispositivo.',
      _ => 'No fue posible conectar con el endpoint /pulse.',
    };
  }

  Future<void> _savePrinter() async {
    final ip = _printerIp.text.trim();
    final port = int.tryParse(_printerPort.text.trim());
    final ipParts = ip.split('.');
    final validIp =
        ipParts.length == 4 &&
        ipParts.every((part) {
          final value = int.tryParse(part);
          return value != null && value >= 0 && value <= 255;
        });
    if (!validIp || port == null || port < 1 || port > 65535) {
      setState(() => _error = 'Ingresa una IP y puerto válidos.');
      return;
    }
    setState(() => _busy = true);
    final controller = ref.read(printerSettingsControllerProvider.notifier);
    final settings = ref.read(printerSettingsControllerProvider);
    await controller.save(settings.copyWith(ipAddress: ip, port: port));
    if (mounted) {
      setState(() => _busy = false);
      _next();
    }
  }

  Future<void> _saveEmail() async {
    final port = int.tryParse(_smtpPort.text.trim());
    final email = _senderEmail.text.trim();
    if (_smtpServer.text.trim().isEmpty ||
        port == null ||
        _smtpUser.text.trim().isEmpty ||
        _smtpPassword.text.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Completa correctamente la configuración SMTP.');
      return;
    }
    setState(() => _busy = true);
    final controller = ref.read(printerSettingsControllerProvider.notifier);
    final settings = ref.read(printerSettingsControllerProvider);
    await controller.save(
      settings.copyWith(
        smtpServer: _smtpServer.text,
        smtpPort: port,
        smtpUsername: _smtpUser.text,
        senderEmail: email,
        senderName: _senderName.text,
        smtpSecurity: _smtpSecurity,
      ),
    );
    await controller.saveEmailPassword(_smtpPassword.text);
    if (mounted) {
      setState(() => _busy = false);
      _next();
    }
  }
}

class _SetupCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SetupCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.borderGrey),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primarySurface,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryBlue),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    ),
  );
}

class _ReadyItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReadyItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: AppColors.success, size: 21),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
