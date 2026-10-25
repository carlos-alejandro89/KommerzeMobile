import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/storage/secure_storage_provider.dart';
import 'package:kommerze_mobile/features/checkout/domain/entities/sale_payment.dart';
import 'package:kommerze_mobile/features/printer/data/services/receipt_email_service.dart';
import 'package:kommerze_mobile/features/printer/data/services/thermal_printer_service.dart';
import 'package:kommerze_mobile/features/printer/domain/entities/sale_receipt.dart';
import 'package:kommerze_mobile/features/printer/presentation/controllers/printer_settings_controller.dart';

class SaleCompletedArgs {
  final SaleReceipt receipt;
  final bool synchronized;
  final String? automaticPrintError;

  const SaleCompletedArgs({
    required this.receipt,
    required this.synchronized,
    this.automaticPrintError,
  });
}

class SaleCompletedScreen extends ConsumerStatefulWidget {
  final SaleCompletedArgs args;

  const SaleCompletedScreen({super.key, required this.args});

  @override
  ConsumerState<SaleCompletedScreen> createState() =>
      _SaleCompletedScreenState();
}

class _SaleCompletedScreenState extends ConsumerState<SaleCompletedScreen> {
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  SaleReceipt get receipt => widget.args.receipt;

  Map<PaymentMethod, double> get paymentsByMethod {
    final result = <PaymentMethod, double>{};
    for (final payment in receipt.payments) {
      result.update(
        payment.method,
        (amount) => amount + payment.amount,
        ifAbsent: () => payment.amount,
      );
    }
    return result;
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          _message = success;
          _messageIsError = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error.toString();
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialMessage = widget.args.automaticPrintError;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: const BoxDecoration(
                        color: AppColors.successSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.success,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '¡Venta exitosa!',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.args.synchronized
                          ? '${receipt.folio} registrada en Kommerze Cloud'
                          : '${receipt.folio} guardada y pendiente de sincronización',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.borderGrey),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D0F2F57),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _TotalRow(
                            label: 'Total vendido',
                            value: receipt.total,
                            featured: true,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 15),
                            child: Divider(height: 1),
                          ),
                          _TotalRow(
                            label: 'Total cobrado',
                            value: receipt.paid,
                          ),
                          const SizedBox(height: 14),
                          ...paymentsByMethod.entries.map(
                            (entry) => _PaymentRow(
                              method: entry.key,
                              amount: entry.value,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_message != null || initialMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _message ??
                            'La venta se guardó, pero no se imprimió: $initialMessage',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _messageIsError || _message == null
                              ? AppColors.error
                              : AppColors.success,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () =>
                                        ReceiptEmailService(
                                          ref.read(secureStorageProvider),
                                        ).send(
                                          receipt,
                                          ref.read(
                                            printerSettingsControllerProvider,
                                          ),
                                        ),
                                    'Recibo enviado a ${receipt.client.email}.',
                                  ),
                            icon: const Icon(Icons.email_outlined),
                            label: const Text('Enviar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () => const ThermalPrinterService()
                                        .printReceipt(
                                          receipt,
                                          ref.read(
                                            printerSettingsControllerProvider,
                                          ),
                                        ),
                                    'Recibo impreso correctamente.',
                                  ),
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Imprimir'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => context.go(AppConstants.salesScreenRoute),
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('Finalizar venta'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool featured;

  const _TotalRow({
    required this.label,
    required this.value,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: featured ? AppColors.navy : AppColors.textGrey,
          fontSize: featured ? 15 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        '\$${value.toStringAsFixed(2)}',
        style: TextStyle(
          color: featured ? AppColors.primaryBlue : AppColors.navy,
          fontSize: featured ? 26 : 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _PaymentRow extends StatelessWidget {
  final PaymentMethod method;
  final double amount;

  const _PaymentRow({required this.method, required this.amount});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(_paymentIcon(method), color: AppColors.primaryBlue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            method.label,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            color: AppColors.success,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

IconData _paymentIcon(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => Icons.payments_outlined,
  PaymentMethod.card => Icons.credit_card_rounded,
  PaymentMethod.transfer => Icons.account_balance_outlined,
  PaymentMethod.check => Icons.receipt_long_outlined,
  PaymentMethod.credit => Icons.schedule_rounded,
  PaymentMethod.other => Icons.more_horiz_rounded,
};
