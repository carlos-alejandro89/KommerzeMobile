import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';

enum InventoryConfirmationKind { backup, recover }

Future<bool> showInventoryConfirmationSheet({
  required BuildContext context,
  required InventoryConfirmationKind kind,
  required Future<void> Function() onConfirm,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: false,
        backgroundColor: Colors.transparent,
        barrierColor: AppColors.navy.withValues(alpha: .64),
        builder: (_) =>
            _InventoryConfirmationSheet(kind: kind, onConfirm: onConfirm),
      ) ??
      false;
}

class _InventoryConfirmationSheet extends StatefulWidget {
  final InventoryConfirmationKind kind;
  final Future<void> Function() onConfirm;

  const _InventoryConfirmationSheet({
    required this.kind,
    required this.onConfirm,
  });

  @override
  State<_InventoryConfirmationSheet> createState() =>
      _InventoryConfirmationSheetState();
}

class _InventoryConfirmationSheetState
    extends State<_InventoryConfirmationSheet> {
  static const _actionColor = Color(0xFFF26A18);
  double _dragOffset = 0;
  bool _dragging = false;
  bool _submitting = false;
  bool _succeeded = false;
  String? _error;

  _InventoryConfirmationCopy get _copy => switch (widget.kind) {
    InventoryConfirmationKind.backup => const _InventoryConfirmationCopy(
      title: 'Confirmar respaldo',
      description:
          'Se enviarán a la nube los precios y existencias actuales de la sucursal.',
      warning:
          'Verifica el inventario antes de continuar; esta copia podrá utilizarse para una recuperación posterior.',
      slideText: 'Desliza para respaldar',
      successTitle: 'Inventario respaldado',
      successMessage: 'La copia de seguridad se guardó correctamente.',
      icon: Icons.cloud_upload_outlined,
    ),
    InventoryConfirmationKind.recover => const _InventoryConfirmationCopy(
      title: 'Confirmar recuperación',
      description:
          'Las existencias locales serán reemplazadas por la última copia almacenada en la nube.',
      warning:
          'Los cambios de inventario posteriores al respaldo podrían perderse.',
      slideText: 'Desliza para recuperar',
      successTitle: 'Inventario recuperado',
      successMessage: 'Las existencias se restauraron correctamente.',
      icon: Icons.cloud_download_outlined,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _succeeded ? _successContent() : _confirmationContent(),
      ),
    );
  }

  Widget _confirmationContent() {
    return Column(
      key: const ValueKey('confirmation'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderGrey,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 82,
          height: 82,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF1E8),
            shape: BoxShape.circle,
          ),
          child: Icon(_copy.icon, color: _actionColor, size: 40),
        ),
        const SizedBox(height: 18),
        Text(
          _copy.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _copy.description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: _actionColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _copy.warning,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _slideControl(),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: AppColors.textGrey,
            ),
            const SizedBox(width: 7),
            Text(
              _submitting
                  ? 'Procesando, no cierres esta pantalla'
                  : 'Desliza hacia la derecha para confirmar',
              style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
            ),
          ],
        ),
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _slideControl() {
    const thumbSize = 54.0;
    const trackPadding = 5.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxOffset = math.max(
          0.0,
          constraints.maxWidth - thumbSize - (trackPadding * 2),
        );
        final currentOffset = _dragOffset.clamp(0.0, maxOffset);
        final progress = maxOffset == 0 ? 0.0 : currentOffset / maxOffset;
        final transitionColor = Color.lerp(
          _actionColor,
          AppColors.success,
          Curves.easeInOut.transform(progress),
        )!;
        final surfaceColor = Color.lerp(
          const Color(0xFFFFFAF7),
          AppColors.successSoft,
          progress,
        )!;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _submitting
              ? null
              : (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: _submitting
              ? null
              : (details) {
                  setState(() {
                    _dragOffset = (_dragOffset + details.delta.dx).clamp(
                      0.0,
                      maxOffset,
                    );
                  });
                },
          onHorizontalDragEnd: _submitting
              ? null
              : (_) {
                  setState(() => _dragging = false);
                  if (_dragOffset >= maxOffset * .82) {
                    _confirm(maxOffset);
                  } else {
                    setState(() => _dragOffset = 0);
                  }
                },
          child: AnimatedContainer(
            duration: _dragging
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            height: 64,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: transitionColor, width: 1.2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: currentOffset > maxOffset * .48 ? .42 : 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 72),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _submitting ? 'Procesando...' : _copy.slideText,
                        maxLines: 1,
                        style: TextStyle(
                          color: transitionColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: trackPadding + currentOffset,
                  child: AnimatedContainer(
                    duration: _dragging
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: transitionColor,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2600143D),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _submitting
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _successContent() {
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .45, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (_, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                color: AppColors.successSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 58,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _copy.successTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _copy.successMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.success,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(double maxOffset) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
      _dragOffset = maxOffset;
    });
    try {
      await widget.onConfirm();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _succeeded = true;
      });
      await Future<void>.delayed(const Duration(seconds: 3));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _dragOffset = 0;
        _error = _cleanError(error);
      });
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst(
      RegExp(r'^(Exception|InventoryException):\s*'),
      '',
    );
  }
}

class _InventoryConfirmationCopy {
  final String title;
  final String description;
  final String warning;
  final String slideText;
  final String successTitle;
  final String successMessage;
  final IconData icon;

  const _InventoryConfirmationCopy({
    required this.title,
    required this.description,
    required this.warning,
    required this.slideText,
    required this.successTitle,
    required this.successMessage,
    required this.icon,
  });
}
