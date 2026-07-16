import 'package:flutter/material.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/custom_text_field.dart';
import 'package:kommerze_mobile/core/widgets/primary_button.dart';

class LoginForm extends StatefulWidget {
  final bool isLoading;
  final void Function(String user, String password) onSubmit;

  const LoginForm({super.key, required this.isLoading, required this.onSubmit});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _rememberMe = false;

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(_emailCtrl.text.trim(), _passCtrl.text);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Inicia sesión',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ingresa tus credenciales para iniciar sesión.',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              label: 'Correo electrónico:',
              hintText: 'nombre@empresa.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              controller: _emailCtrl,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El correo electrónico es requerido';
                }
                if (!value.contains('@')) {
                  return 'Ingresa un correo electrónico válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Contraseña:',
              hintText: '********',
              prefixIcon: Icons.lock_outline,
              obscureText: true,
              controller: _passCtrl,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Contraseña es requerida';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                    ),
                    const Text(
                      'Recordarme',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 14),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '¿Olvidaste la contraseña?',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: widget.isLoading ? "Iniciando sesion..." : 'Iniciar Sesión',
              paddingVertical: 16,
              onPressed: _handleLogin,
              isLoading: widget.isLoading,
              bg: AppColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
