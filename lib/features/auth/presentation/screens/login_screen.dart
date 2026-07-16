import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/login_form.dart';
import 'package:kommerze_mobile/features/auth/presentation/controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // El logotipo permanece en el estado final alcanzado en el Splash.
  late final Animation<Offset> _truckSlide;
  late final Animation<double> _textReveal;
  late final Animation<double> _logoTop;
  // El formulario entra suavemente desde abajo.
  late final Animation<double> _formSlide;
  late final Animation<double> _formFade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _truckSlide = const AlwaysStoppedAnimation(Offset.zero);
    _textReveal = const AlwaysStoppedAnimation(1.0);
    _logoTop = const AlwaysStoppedAnimation(0.15);

    _formSlide = Tween<double>(
      begin: 48,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _formFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (old, current) {
      if (current.hasError && !current.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(current.error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            children: [
              // ── Gradiente FUERA del SafeArea: cubre todo el body ──────────
              // Incluyendo el área del home indicator (bottom inset), igual
              // que el Container del LoginScreen normal.
              Opacity(
                opacity: _formFade.value,
                child: const SizedBox.expand(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.gradienteInicio,
                          AppColors.gradienteFin,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Contenido DENTRO del SafeArea ─────────────────────────────
              ClipRect(
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availH = constraints.maxHeight;
                      final topPadding = (availH * _logoTop.value - 40).clamp(
                        0.0,
                        availH,
                      );

                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: availH),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: topPadding),

                              // Logo animado
                              SlideTransition(
                                position: _truckSlide,
                                child: Center(
                                  child: SizedBox(
                                    width: 235,
                                    child: ClipRect(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        widthFactor:
                                            0.42 + (_textReveal.value * 0.58),
                                        child: Image.asset(
                                          'assets/img/kommerze_logo.png',
                                          width: 235,
                                          height: 166,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Form con animación de slide + fade
                              ClipRect(
                                child: Transform.translate(
                                  offset: Offset(0, _formSlide.value),
                                  child: Opacity(
                                    opacity: _formFade.value,
                                    child: LoginForm(
                                      isLoading: authState.isLoading,
                                      onSubmit: (user, password) => ref
                                          .read(authControllerProvider.notifier)
                                          .login(
                                            user: user,
                                            password: password,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
