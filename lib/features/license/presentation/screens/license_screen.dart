import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/device/device_identity_service.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/core/widgets/custom_text_field.dart';
import 'package:kommerze_mobile/core/widgets/primary_button.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_details.dart';
import 'package:kommerze_mobile/features/license/presentation/controllers/license_activation_controller.dart';

class LicenseScreen extends ConsumerStatefulWidget {
  const LicenseScreen({super.key});

  @override
  ConsumerState<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends ConsumerState<LicenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _machineIdController = TextEditingController();
  final _licenseKeyController = TextEditingController();
  final _deviceNameController = TextEditingController();
  bool _loadingDeviceIdentity = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceIdentity();
  }

  Future<void> _loadDeviceIdentity() async {
    try {
      final identity = await ref.read(deviceIdentityServiceProvider).load();
      if (!mounted) return;
      _machineIdController.text = identity.id;
      if (_deviceNameController.text.trim().isEmpty) {
        _deviceNameController.text = identity.name;
      }
    } finally {
      if (mounted) setState(() => _loadingDeviceIdentity = false);
    }
  }

  @override
  void dispose() {
    _machineIdController.dispose();
    _licenseKeyController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(licenseActivationControllerProvider.notifier)
        .activate(
          machineId: _machineIdController.text,
          licenseKey: _licenseKeyController.text,
          deviceName: _deviceNameController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final activation = ref.watch(licenseActivationControllerProvider);
    final licenseDetails = ref.watch(licenseDetailsProvider);

    ref.listen(licenseActivationControllerProvider, (previous, next) {
      if (next.isLoading) return;
      if (next.hasError) {
        _showToast(context, success: false, message: next.error.toString());
        return;
      }
      final result = next.value;
      if (result != null && previous?.value != result) {
        _showToast(context, success: result.success, message: result.message);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Licencia',
            height: 96 + MediaQuery.paddingOf(context).top,
            showBackButton: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: licenseDetails.when(
                    data: (details) {
                      if (details != null) {
                        return _LicenseDetailsView(details: details);
                      }
                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_user_outlined,
                                  color: AppColors.primaryBlue,
                                  size: 32,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Configura tu licencia',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Ingresa los datos asignados a este dispositivo para habilitar Kommerze.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.borderGrey),
                              ),
                              child: Column(
                                children: [
                                  CustomTextField(
                                    label: 'ID del Dispositivo:',
                                    hintText: 'Obteniendo identificador...',
                                    prefixIcon: Icons.memory_rounded,
                                    controller: _machineIdController,
                                    readOnly: true,
                                    validator: _required(
                                      'El ID del dispositivo',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  CustomTextField(
                                    label: 'Clave de licencia:',
                                    hintText: 'XXXX-XXXX-XXXX-XXXX',
                                    prefixIcon: Icons.key_rounded,
                                    controller: _licenseKeyController,
                                    validator: _required(
                                      'La clave de licencia',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  CustomTextField(
                                    label: 'Nombre del dispositivo:',
                                    hintText: 'Caja principal',
                                    prefixIcon: Icons.devices_rounded,
                                    controller: _deviceNameController,
                                    validator: _required(
                                      'El nombre del dispositivo',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            PrimaryButton(
                              text: _loadingDeviceIdentity
                                  ? 'Identificando dispositivo...'
                                  : activation.isLoading
                                  ? 'Activando licencia...'
                                  : 'Activar licencia',
                              onPressed: _submit,
                              isLoading:
                                  activation.isLoading ||
                                  _loadingDeviceIdentity,
                              paddingVertical: 15,
                              bg: AppColors.primaryBlue,
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => Form(
                      key: _formKey,
                      child: const Text(
                        'No fue posible consultar la licencia local.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? Function(String?) _required(String field) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$field es requerido';
      }
      return null;
    };
  }

  void _showToast(
    BuildContext context, {
    required bool success,
    required String message,
  }) {
    final color = success ? AppColors.success : AppColors.error;
    final surface = success ? AppColors.successSoft : AppColors.errorSoft;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: surface,
          elevation: 1,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withValues(alpha: 0.22)),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }
}

class _LicenseDetailsView extends StatelessWidget {
  final LicenseDetails details;

  const _LicenseDetailsView({required this.details});

  @override
  Widget build(BuildContext context) {
    final license = details.license;
    final branch = details.branch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withValues(alpha: .18)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_rounded, color: AppColors.success, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Licencia activa',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Este dispositivo está habilitado para operar.',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _DetailsCard(
          title: 'Datos de la licencia',
          icon: Icons.workspace_premium_outlined,
          rows: [
            _Detail('Dispositivo', license.deviceName),
            _Detail('ID del dispositivo', license.machineId),
            _Detail('Clave', license.licenseKeyHint),
            if (license.validityMonths != null)
              _Detail('Vigencia', '${license.validityMonths} meses'),
            _Detail('Activación', _formatDate(license.activatedAt)),
            if (license.expiresAt != null)
              _Detail('Expiración', _formatDate(license.expiresAt!)),
            if (license.appVersion.isNotEmpty)
              _Detail('Versión de la app', license.appVersion),
          ],
        ),
        const SizedBox(height: 16),
        _DetailsCard(
          title: 'Sucursal asignada',
          icon: Icons.storefront_outlined,
          rows: [
            _Detail('Sucursal', branch.name),
            _Detail('Clave', branch.code),
            if (branch.address.isNotEmpty) _Detail('Dirección', branch.address),
            _Detail('Ubicación', '${branch.city}, ${branch.state}'),
            if (branch.postalCode.isNotEmpty)
              _Detail('Código postal', branch.postalCode),
            if (branch.phone.isNotEmpty) _Detail('Teléfono', branch.phone),
            if (branch.email.isNotEmpty) _Detail('Correo', branch.email),
            if (branch.cfdiSeries.isNotEmpty)
              _Detail('Serie CFDI', branch.cfdiSeries),
          ],
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

class _Detail {
  final String label;
  final String value;
  const _Detail(this.label, this.value);
}

class _DetailsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_Detail> rows;

  const _DetailsCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primaryBlue),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(
                      rows[index].label,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rows[index].value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index < rows.length - 1)
              const Divider(height: 1, color: AppColors.borderGrey),
          ],
        ],
      ),
    );
  }
}
