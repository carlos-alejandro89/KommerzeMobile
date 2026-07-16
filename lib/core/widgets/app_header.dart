import 'package:flutter/material.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';

/// Encabezado reutilizable de Kommerze.
///
/// Mantiene el borde inferior recto para enlazar limpiamente con el contenido
/// de cualquier pantalla. [content] permite crear variantes expandidas.
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double height;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? content;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.height = 96,
    this.showBackButton = false,
    this.onBack,
    this.actions = const [],
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF001B60), Color(0xFF073E9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            bottom: -110,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brightBlue.withValues(alpha: .08),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (showBackButton) ...[
                          IconButton(
                            onPressed:
                                onBack ?? () => Navigator.maybePop(context),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 27,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.2,
                                ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ...actions,
                      ],
                    ),
                  ),
                  if (content != null) ...[
                    const SizedBox(height: 10),
                    Expanded(child: content!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
