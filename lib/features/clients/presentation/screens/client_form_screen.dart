import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/core/widgets/primary_button.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:kommerze_mobile/features/clients/presentation/controllers/clients_controller.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  final Client? client;
  const ClientFormScreen({super.key, this.client});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _rfc;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _credit;
  late final TextEditingController _days;
  bool _saving = false;

  bool get _editing => widget.client != null;

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _name = TextEditingController(text: client?.name ?? '');
    _rfc = TextEditingController(text: client?.rfc ?? '');
    _email = TextEditingController(text: client?.email ?? '');
    _phone = TextEditingController(text: client?.phone ?? '');
    _credit = TextEditingController(
      text: client?.creditAmount.toStringAsFixed(2) ?? '0.00',
    );
    _days = TextEditingController(text: '${client?.creditDays ?? 0}');
  }

  @override
  void dispose() {
    for (final controller in [_name, _rfc, _email, _phone, _credit, _days]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.lightBackground,
    body: Column(
      children: [
        AppHeader(
          title: _editing ? 'Editar cliente' : 'Nuevo cliente',
          subtitle: _editing
              ? 'Actualiza la información del cliente'
              : 'Registra un cliente en Kommerze',
          height: 104 + MediaQuery.paddingOf(context).top,
          showBackButton: true,
          onBack: context.pop,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FormSection(
                        icon: Icons.business_outlined,
                        title: 'Información fiscal',
                        subtitle: 'Datos de identificación del cliente',
                        children: [
                          _field(
                            _name,
                            'Nombre o razón social',
                            icon: Icons.person_outline_rounded,
                            required: true,
                          ),
                          _field(
                            _rfc,
                            'RFC',
                            icon: Icons.badge_outlined,
                            required: true,
                            caps: true,
                            validator: _rfcValidator,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        icon: Icons.contact_phone_outlined,
                        title: 'Contacto',
                        subtitle: 'Medios para contactar al cliente',
                        children: [
                          _field(
                            _email,
                            'Correo electrónico',
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress,
                            validator: _emailValidator,
                          ),
                          _field(
                            _phone,
                            'Teléfono',
                            icon: Icons.phone_outlined,
                            type: TextInputType.phone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Condiciones de crédito',
                        subtitle: 'Límite y plazo autorizado',
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _field(
                                  _credit,
                                  'Monto de crédito',
                                  icon: Icons.attach_money_rounded,
                                  decimal: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _field(
                                  _days,
                                  'Días de crédito',
                                  icon: Icons.calendar_today_outlined,
                                  integer: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        text: _saving
                            ? 'Guardando cliente...'
                            : _editing
                            ? 'Guardar cambios'
                            : 'Crear cliente',
                        onPressed: _save,
                        isLoading: _saving,
                        paddingVertical: 15,
                        bg: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    required IconData icon,
    bool required = false,
    bool caps = false,
    bool decimal = false,
    bool integer = false,
    TextInputType? type,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: TextFormField(
      controller: controller,
      textCapitalization: caps
          ? TextCapitalization.characters
          : TextCapitalization.none,
      keyboardType:
          type ??
          (decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : integer
              ? TextInputType.number
              : TextInputType.text),
      inputFormatters: [
        if (decimal)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        if (integer) FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      validator:
          validator ??
          (required
              ? (value) => value == null || value.trim().isEmpty
                    ? '$label es requerido'
                    : null
              : null),
    ),
  );

  String? _rfcValidator(String? value) {
    final rfc = value?.trim() ?? '';
    if (rfc.isEmpty) return 'RFC es requerido';
    if (rfc.length < 12 || rfc.length > 13) return 'Ingresa un RFC válido';
    return null;
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final draft = ClientDraft(
      name: _name.text,
      rfc: _rfc.text,
      email: _email.text,
      phone: _phone.text,
      creditAmount: double.tryParse(_credit.text) ?? 0,
      creditDays: int.tryParse(_days.text) ?? 0,
    );
    final controller = ref.read(clientsControllerProvider.notifier);
    final success = _editing
        ? await controller.updateClient(widget.client!, draft)
        : await controller.create(draft);
    if (!mounted) return;
    if (success) {
      context.pop(true);
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.read(clientsControllerProvider.notifier).lastError ??
              'No fue posible guardar el cliente.',
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _FormSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 3),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.borderGrey),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primaryLight,
              child: Icon(icon, color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        ...children,
      ],
    ),
  );
}
