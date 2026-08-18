import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/payment_method_card.dart';
import 'package:kommerze_mobile/features/collections/domain/entities/collection_models.dart';

class CollectionPaymentSheet extends StatefulWidget {
  final List<PaymentFormOption> paymentForms;
  final double suggestedAmount;

  const CollectionPaymentSheet({
    super.key,
    required this.paymentForms,
    required this.suggestedAmount,
  });

  static Future<CollectionPaymentInput?> show(
    BuildContext context, {
    required List<PaymentFormOption> paymentForms,
    required double suggestedAmount,
  }) {
    return showModalBottomSheet<CollectionPaymentInput>(
      context: context,
      isScrollControlled: true,
      requestFocus: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.navy.withValues(alpha: .55),
      builder: (_) => CollectionPaymentSheet(
        paymentForms: paymentForms,
        suggestedAmount: suggestedAmount,
      ),
    );
  }

  @override
  State<CollectionPaymentSheet> createState() => _CollectionPaymentSheetState();
}

class _CollectionPaymentSheetState extends State<CollectionPaymentSheet> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  PaymentFormOption? _selected;

  double get amount =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.paymentForms.firstOrNull;
    if (widget.suggestedAmount > 0) {
      _amount.text = widget.suggestedAmount.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 11, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.add_card_rounded,
                        color: AppColors.primaryBlue,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agregar forma de pago',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Registra el dinero recibido. Puedes combinar varias formas.',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.paymentForms.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Sincroniza el catálogo Formas de pago antes de registrar un cobro.',
                      style: TextStyle(color: AppColors.error, fontSize: 12.5),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 9.0;
                      final itemWidth =
                          (constraints.maxWidth - spacing * 2) / 3;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: widget.paymentForms
                            .map((form) {
                              final selected = _selected?.guid == form.guid;
                              return SizedBox(
                                width: itemWidth,
                                child: PaymentMethodCard(
                                  label: form.label,
                                  icon: _paymentIcon(form.key),
                                  color: _paymentColor(form.key),
                                  selected: selected,
                                  onTap: () => setState(() => _selected = form),
                                ),
                              );
                            })
                            .toList(growable: false),
                      );
                    },
                  ),
                const SizedBox(height: 18),
                const Text(
                  'Monto recibido',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: _amount,
                  autofocus: false,
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
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 13),
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
                  autofocus: false,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Operación, autorización o comentario...',
                    filled: true,
                    fillColor: AppColors.primarySurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: amount > .001 && _selected != null
                        ? () => Navigator.pop(
                            context,
                            CollectionPaymentInput(
                              paymentForm: _selected!,
                              amount: amount,
                              reference: _reference.text.trim(),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.add_card_rounded, size: 19),
                    label: Text('Agregar ${_money(amount)}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
}

IconData _paymentIcon(String key) => switch (key) {
  '01' => Icons.payments_outlined,
  '02' => Icons.receipt_long_outlined,
  '03' => Icons.account_balance_outlined,
  '04' || '28' || '29' => Icons.credit_card_rounded,
  _ => Icons.account_balance_wallet_outlined,
};

Color _paymentColor(String key) => switch (key) {
  '01' => AppColors.success,
  '04' || '28' || '29' => AppColors.primaryBlue,
  '03' => const Color(0xFF7138C8),
  '02' => const Color(0xFF247B9E),
  _ => AppColors.textGrey,
};

String _money(double value) => '\$${value.toStringAsFixed(2)}';
