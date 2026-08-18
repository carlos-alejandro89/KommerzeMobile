import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/payment_method_card.dart';
import 'package:kommerze_mobile/features/checkout/domain/entities/sale_payment.dart';

class PaymentDraft {
  final PaymentMethod method;
  final double amount;
  final String reference;
  const PaymentDraft({
    required this.method,
    required this.amount,
    required this.reference,
  });
}

class AddPaymentSheet extends StatefulWidget {
  final double pending;
  final double availableCredit;

  const AddPaymentSheet({
    super.key,
    required this.pending,
    required this.availableCredit,
  });

  static Future<PaymentDraft?> show(
    BuildContext context, {
    required double pending,
    required double availableCredit,
  }) => showModalBottomSheet<PaymentDraft>(
    context: context,
    isScrollControlled: true,
    requestFocus: false,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        AddPaymentSheet(pending: pending, availableCredit: availableCredit),
  );

  @override
  State<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<AddPaymentSheet> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  double get amount => double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
  double get maximum => switch (_method) {
    PaymentMethod.cash => double.infinity,
    PaymentMethod.credit =>
      widget.pending.clamp(0, widget.availableCredit).toDouble(),
    _ => widget.pending,
  };
  double get change => _method == PaymentMethod.cash && amount > widget.pending
      ? amount - widget.pending
      : 0;
  bool get valid =>
      amount > 0 && (_method == PaymentMethod.cash || amount <= maximum);

  @override
  void initState() {
    super.initState();
    _amount.text = widget.pending.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _select(PaymentMethod method) {
    if (method == PaymentMethod.credit && widget.availableCredit <= 0) return;
    setState(() {
      _method = method;
      if (maximum.isFinite && amount > maximum) {
        _amount.text = maximum.toStringAsFixed(2);
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 180),
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 11, 20, 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderGrey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Agregar pago',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Saldo por cubrir: ${_money(widget.pending)}',
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 9.0;
                  final itemWidth = (constraints.maxWidth - spacing * 2) / 3;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: PaymentMethod.values.map((method) {
                      final disabled =
                          method == PaymentMethod.credit &&
                          widget.availableCredit <= 0;
                      return SizedBox(
                        width: itemWidth,
                        child: PaymentMethodCard(
                          label: method.label,
                          icon: _icon(method),
                          color: _methodColor(method),
                          selected: _method == method,
                          enabled: !disabled,
                          onTap: () => _select(method),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              if (_method == PaymentMethod.credit) ...[
                const SizedBox(height: 8),
                Text(
                  'Crédito disponible: ${_money(widget.availableCredit)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                _method == PaymentMethod.cash ? 'Efectivo recibido' : 'Monto',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  hintText: '0.00',
                  filled: true,
                  fillColor: AppColors.primarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_method != PaymentMethod.cash && amount > maximum)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'El monto no puede superar ${_money(maximum)}.',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              if (_method == PaymentMethod.cash && change > 0)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.currency_exchange_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Cambio a entregar',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _money(change),
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              const Text(
                'Referencia o nota (opcional)',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _reference,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Número de operación, autorización, notas...',
                  filled: true,
                  fillColor: AppColors.primarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: valid
                      ? () => Navigator.pop(
                          context,
                          PaymentDraft(
                            method: _method,
                            amount: amount,
                            reference: _reference.text,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.add_card_rounded, size: 20),
                  label: Text('Agregar ${_money(amount)}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    disabledBackgroundColor: AppColors.borderGrey,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

IconData _icon(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => Icons.payments_outlined,
  PaymentMethod.card => Icons.credit_card_rounded,
  PaymentMethod.transfer => Icons.account_balance_outlined,
  PaymentMethod.check => Icons.receipt_long_outlined,
  PaymentMethod.credit => Icons.schedule_rounded,
  PaymentMethod.other => Icons.more_horiz_rounded,
};

Color _methodColor(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => AppColors.success,
  PaymentMethod.card => AppColors.primaryBlue,
  PaymentMethod.transfer => const Color(0xFF7138C8),
  PaymentMethod.check => const Color(0xFF247B9E),
  PaymentMethod.credit => const Color(0xFFE66A16),
  PaymentMethod.other => AppColors.textGrey,
};

String _money(double value) => '\$${value.toStringAsFixed(2)}';
