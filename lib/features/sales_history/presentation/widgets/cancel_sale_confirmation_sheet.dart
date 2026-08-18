import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_history_item.dart';

Future<bool> showCancelSaleConfirmationSheet({
  required BuildContext context,
  required SaleHistoryItem sale,
  required Future<void> Function() onConfirm,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.navy.withValues(alpha: .64),
      builder: (_) => _CancelSaleSheet(sale: sale, onConfirm: onConfirm),
    ) ??
    false;

class _CancelSaleSheet extends StatefulWidget {
  final SaleHistoryItem sale;
  final Future<void> Function() onConfirm;
  const _CancelSaleSheet({required this.sale, required this.onConfirm});

  @override
  State<_CancelSaleSheet> createState() => _CancelSaleSheetState();
}

class _CancelSaleSheetState extends State<_CancelSaleSheet> {
  double _offset = 0;
  bool _dragging = false;
  bool _submitting = false;
  bool _success = false;
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
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: _success ? _successView() : _confirmationView(),
    ),
  );

  Widget _confirmationView() => Column(
    key: const ValueKey('confirm'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.borderGrey,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      const SizedBox(height: 22),
      Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: Color(0xFFFFEEE9),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.remove_shopping_cart_outlined,
          color: AppColors.error,
          size: 34,
        ),
      ),
      const SizedBox(height: 15),
      const Text(
        'Cancelar venta',
        style: TextStyle(
          color: AppColors.navy,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '${widget.sale.formattedFolio} · ${widget.sale.clientName}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textGrey, fontSize: 12.5),
      ),
      const SizedBox(height: 15),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.inventory_2_outlined, color: AppColors.error, size: 20),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'La venta quedará cancelada y sus artículos regresarán al inventario. Esta acción no puede deshacerse.',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 11),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.error, fontSize: 11.5),
        ),
      ],
      const SizedBox(height: 20),
      _slider(),
      const SizedBox(height: 8),
      const Text(
        'Desliza hacia la derecha para confirmar',
        style: TextStyle(color: AppColors.textGrey, fontSize: 11),
      ),
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context, false),
        child: const Text('Volver'),
      ),
    ],
  );

  Widget _slider() => LayoutBuilder(
    builder: (context, constraints) {
      const thumb = 54.0;
      const padding = 5.0;
      final max = math.max(0.0, constraints.maxWidth - thumb - padding * 2);
      final current = _offset.clamp(0.0, max);
      final progress = max == 0 ? 0.0 : current / max;
      final color = Color.lerp(AppColors.error, AppColors.success, progress)!;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _submitting
            ? null
            : (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: _submitting
            ? null
            : (details) => setState(() {
                _offset = (_offset + details.delta.dx).clamp(0.0, max);
              }),
        onHorizontalDragEnd: _submitting
            ? null
            : (_) {
                setState(() => _dragging = false);
                if (_offset >= max * .82) {
                  _confirm(max);
                } else {
                  setState(() => _offset = 0);
                }
              },
        child: AnimatedContainer(
          duration: _dragging
              ? Duration.zero
              : const Duration(milliseconds: 220),
          height: 64,
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFFFF1ED),
              AppColors.successSoft,
              progress,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: color, width: 1.2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 70),
                child: FittedBox(
                  child: Text(
                    _submitting
                        ? 'Cancelando venta...'
                        : 'Desliza para cancelar',
                    style: TextStyle(
                      color: color,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                left: padding + current,
                child: Container(
                  width: thumb,
                  height: thumb,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
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
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _successView() => const Padding(
    key: ValueKey('success'),
    padding: EdgeInsets.symmetric(vertical: 38),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 46,
          backgroundColor: AppColors.successSoft,
          child: Icon(Icons.check_rounded, color: AppColors.success, size: 52),
        ),
        SizedBox(height: 18),
        Text(
          'Venta cancelada',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Los artículos regresaron al inventario.',
          style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
        ),
      ],
    ),
  );

  Future<void> _confirm(double max) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
      _offset = max;
    });
    try {
      await widget.onConfirm();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _offset = 0;
        _error = error.toString();
      });
    }
  }
}
