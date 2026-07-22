import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';

Future<bool> showCollectionConfirmationSheet({
  required BuildContext context,
  required String clientName,
  required double receivedAmount,
  required double appliedAmount,
  required double creditBalance,
  required int accountCount,
  required Future<void> Function() onConfirm,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: AppColors.navy.withValues(alpha: .64),
        builder: (_) => _CollectionConfirmationSheet(
          clientName: clientName,
          receivedAmount: receivedAmount,
          appliedAmount: appliedAmount,
          creditBalance: creditBalance,
          accountCount: accountCount,
          onConfirm: onConfirm,
        ),
      ) ??
      false;
}

class _CollectionConfirmationSheet extends StatefulWidget {
  final String clientName;
  final double receivedAmount;
  final double appliedAmount;
  final double creditBalance;
  final int accountCount;
  final Future<void> Function() onConfirm;

  const _CollectionConfirmationSheet({
    required this.clientName,
    required this.receivedAmount,
    required this.appliedAmount,
    required this.creditBalance,
    required this.accountCount,
    required this.onConfirm,
  });

  @override
  State<_CollectionConfirmationSheet> createState() =>
      _CollectionConfirmationSheetState();
}

class _CollectionConfirmationSheetState
    extends State<_CollectionConfirmationSheet> {
  double _dragOffset = 0;
  bool _dragging = false;
  bool _submitting = false;
  bool _succeeded = false;
  String? _error;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: SingleChildScrollView(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _succeeded ? _successContent() : _confirmationContent(),
      ),
    ),
  );

  Widget _confirmationContent() => Column(
    key: const ValueKey('confirmation'),
    mainAxisSize: MainAxisSize.min,
    children: [
      _handle(),
      const SizedBox(height: 22),
      Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: AppColors.primaryLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.payments_outlined,
          color: AppColors.primaryBlue,
          size: 34,
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Confirmar cobro',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.navy,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        widget.clientName,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textGrey,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            _SummaryRow(
              label: 'Monto recibido',
              value: _money(widget.receivedAmount),
              emphasized: true,
            ),
            const Divider(height: 18),
            _SummaryRow(
              label:
                  'Aplicado a ${widget.accountCount} ${widget.accountCount == 1 ? 'cuenta' : 'cuentas'}',
              value: _money(widget.appliedAmount),
            ),
            if (widget.creditBalance > .001) ...[
              const Divider(height: 18),
              _SummaryRow(
                label: 'Saldo a favor',
                value: _money(widget.creditBalance),
                success: true,
              ),
            ],
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
                ? 'Registrando, no cierres esta pantalla'
                : 'Desliza hacia la derecha para confirmar',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 11.5),
          ),
        ],
      ),
      TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
    ],
  );

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
          AppColors.primaryBlue,
          AppColors.success,
          Curves.easeInOut.transform(progress),
        )!;
        final surfaceColor = Color.lerp(
          AppColors.primarySurface,
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
              : (details) => setState(() {
                  _dragOffset = (_dragOffset + details.delta.dx).clamp(
                    0.0,
                    maxOffset,
                  );
                }),
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
                    padding: const EdgeInsets.symmetric(horizontal: 70),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _submitting
                            ? 'Registrando cobro...'
                            : 'Desliza para registrar',
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

  Widget _successContent() => Padding(
    key: const ValueKey('success'),
    padding: const EdgeInsets.symmetric(vertical: 34),
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
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 54,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Cobro registrado',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_money(widget.receivedAmount)} recibidos de ${widget.clientName}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

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
        _error = error.toString().replaceFirst(
          RegExp(r'^(Exception|CollectionsLocalException):\s*'),
          '',
        );
      });
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  final bool success;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: success ? AppColors.success : AppColors.navy,
          fontSize: emphasized ? 16 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

Widget _handle() => Center(
  child: Container(
    width: 42,
    height: 4,
    decoration: BoxDecoration(
      color: AppColors.borderGrey,
      borderRadius: BorderRadius.circular(4),
    ),
  ),
);

String _money(double value) => '\$${value.toStringAsFixed(2)}';
