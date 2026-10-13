import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/network/url_builder.dart';
import 'package:kommerze_mobile/core/setup/app_setup_controller.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/auth/presentation/controllers/auth_controller.dart';

class ServerSettingsScreen extends ConsumerStatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  ConsumerState<ServerSettingsScreen> createState() =>
      _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen> {
  late final TextEditingController _url;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(
      text: ref.read(appSetupControllerProvider).baseUrl,
    );
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.lightBackground,
    body: Column(
      children: [
        const AppHeader(
          title: 'Servidor',
          subtitle: 'Conexión con Kommerze',
          height: 106,
          showBackButton: true,
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderGrey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Servidor de la aplicación',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Al cambiar de servidor se cerrará la sesión y será necesario sincronizar nuevamente los catálogos.',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Dirección HTTPS',
                            prefixIcon: Icon(Icons.link_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_done_outlined),
                          label: Text(
                            _saving ? 'Verificando...' : 'Verificar y guardar',
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
      ],
    ),
  );

  Future<void> _save() async {
    final value = AppSetupController.normalizeBaseUrl(_url.text);
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => _error = 'Ingresa una dirección HTTPS válida.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
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
      final changed = value != ref.read(appSetupControllerProvider).baseUrl;
      if (changed) {
        await ref.read(authControllerProvider.notifier).logout();
      }
      await ref.read(appSetupControllerProvider.notifier).saveBaseUrl(value);
      if (changed) {
        if (mounted) context.go(AppConstants.loginScreenRoute);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La conexión funciona correctamente.')),
        );
      }
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _dioConnectionMessage(error));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
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
}
