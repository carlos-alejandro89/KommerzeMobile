import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/collections/data/repositories/collections_repository.dart';
import 'package:kommerze_mobile/features/collections/domain/entities/collection_models.dart';
import 'package:kommerze_mobile/features/collections/presentation/controllers/collections_controller.dart';
import 'package:kommerze_mobile/features/collections/presentation/widgets/collection_confirmation_sheet.dart';
import 'package:kommerze_mobile/features/collections/presentation/widgets/collection_payment_sheet.dart';

class RegisterCollectionScreen extends ConsumerStatefulWidget {
  final String clientGuid;

  const RegisterCollectionScreen({super.key, required this.clientGuid});

  @override
  ConsumerState<RegisterCollectionScreen> createState() =>
      _RegisterCollectionScreenState();
}

class _RegisterCollectionScreenState
    extends ConsumerState<RegisterCollectionScreen> {
  final _payments = <CollectionPaymentInput>[];
  CollectionPreview? _preview;
  bool _loadingPreview = false;
  bool _submitting = false;
  int _previewRequest = 0;

  double get _total =>
      _payments.fold(0, (sum, payment) => sum + payment.amount);

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(
      collectionClientDetailProvider(widget.clientGuid),
    );
    final formsState = ref.watch(collectionPaymentFormsProvider);
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Registrar cobro',
            subtitle: detailState.value?.client.name,
            height: 104 + MediaQuery.paddingOf(context).top,
            showBackButton: true,
            onBack: () {
              if (!_submitting) context.pop();
            },
          ),
          Expanded(
            child: detailState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (detail) => _content(
                detail,
                formsState.value ?? const <PaymentFormOption>[],
                formsLoading: formsState.isLoading,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(
    CollectionClientDetail detail,
    List<PaymentFormOption> forms, {
    required bool formsLoading,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _BalanceHeader(detail: detail),
        const SizedBox(height: 12),
        _Section(
          title: 'Formas de pago',
          icon: Icons.account_balance_wallet_outlined,
          child: Column(
            children: [
              if (_payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Agrega el dinero recibido para calcular su aplicación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                  ),
                )
              else
                for (var index = 0; index < _payments.length; index++) ...[
                  _PaymentRow(
                    payment: _payments[index],
                    onRemove: _submitting
                        ? null
                        : () {
                            setState(() => _payments.removeAt(index));
                            _refreshPreview();
                          },
                  ),
                  if (index < _payments.length - 1) const Divider(height: 16),
                ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: formsLoading || _submitting
                      ? null
                      : () => _addPayment(forms, detail.client.balance),
                  icon: formsLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline_rounded, size: 19),
                  label: const Text('Agregar forma de pago'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: AppColors.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Aplicación automática',
          icon: Icons.auto_awesome_rounded,
          child: _previewContent(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'El cobro se aplica primero a la cuenta con vencimiento más antiguo. Las cuentas en aclaración se omiten.',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _payments.isNotEmpty && !_submitting && _preview != null
                ? () => _register(detail.client.name)
                : null,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Icon(Icons.verified_outlined, size: 20),
            label: Text(
              _submitting
                  ? 'Registrando cobro...'
                  : 'Confirmar ${_money(_total)}',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.borderGrey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewContent() {
    if (_loadingPreview) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final preview = _preview;
    if (preview == null || _payments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'La distribución aparecerá al agregar una forma de pago.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGrey, fontSize: 12),
        ),
      );
    }
    return Column(
      children: [
        for (final allocation in preview.allocations) ...[
          _AllocationRow(allocation: allocation),
          const Divider(height: 14),
        ],
        _TotalRow(label: 'Recibido', value: preview.receivedAmount),
        const SizedBox(height: 7),
        _TotalRow(label: 'Aplicado a cuentas', value: preview.appliedAmount),
        if (preview.creditBalance > .001) ...[
          const SizedBox(height: 7),
          _TotalRow(
            label: 'Saldo a favor',
            value: preview.creditBalance,
            color: AppColors.success,
          ),
        ],
      ],
    );
  }

  Future<void> _addPayment(
    List<PaymentFormOption> forms,
    double currentBalance,
  ) async {
    final suggested = (currentBalance - _total)
        .clamp(0, double.infinity)
        .toDouble();
    final payment = await CollectionPaymentSheet.show(
      context,
      paymentForms: forms,
      suggestedAmount: suggested,
    );
    if (payment == null || !mounted) return;
    setState(() => _payments.add(payment));
    await _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    final request = ++_previewRequest;
    if (_payments.isEmpty) {
      setState(() {
        _preview = null;
        _loadingPreview = false;
      });
      return;
    }
    setState(() => _loadingPreview = true);
    try {
      final preview = await ref
          .read(collectionsRepositoryProvider)
          .preview(widget.clientGuid, List.unmodifiable(_payments));
      if (!mounted || request != _previewRequest) return;
      setState(() {
        _preview = preview;
        _loadingPreview = false;
      });
    } catch (error) {
      if (!mounted || request != _previewRequest) return;
      setState(() => _loadingPreview = false);
      _message(error.toString(), false);
    }
  }

  Future<void> _register(String clientName) async {
    final preview = _preview;
    if (preview == null) return;
    setState(() => _submitting = true);
    final confirmed = await showCollectionConfirmationSheet(
      context: context,
      clientName: clientName,
      receivedAmount: preview.receivedAmount,
      appliedAmount: preview.appliedAmount,
      creditBalance: preview.creditBalance,
      accountCount: preview.allocations.length,
      onConfirm: () async {
        await ref
            .read(collectionsRepositoryProvider)
            .register(
              clientGuid: widget.clientGuid,
              payments: List.unmodifiable(_payments),
            );
        ref.invalidate(collectionClientDetailProvider(widget.clientGuid));
        ref.invalidate(collectionsDashboardProvider);
      },
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (confirmed) context.pop(true);
  }

  void _message(String message, bool success) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
  }
}

class _BalanceHeader extends StatelessWidget {
  final CollectionClientDetail detail;
  const _BalanceHeader({required this.detail});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF001B60), Color(0xFF0647CF)],
      ),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          color: Colors.white,
          size: 34,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saldo pendiente del cliente',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                _money(detail.client.balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${detail.accounts.where((item) => !item.blocked).length} aplicables',
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.borderGrey.withValues(alpha: .75)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _PaymentRow extends StatelessWidget {
  final CollectionPaymentInput payment;
  final VoidCallback? onRemove;
  const _PaymentRow({required this.payment, required this.onRemove});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.payments_outlined,
          color: AppColors.success,
          size: 20,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              payment.paymentForm.label,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (payment.reference.isNotEmpty)
              Text(
                payment.reference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textGrey, fontSize: 10),
              ),
          ],
        ),
      ),
      Text(
        _money(payment.amount),
        style: const TextStyle(
          color: AppColors.success,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 19),
      ),
    ],
  );
}

class _AllocationRow extends StatelessWidget {
  final CollectionAllocation allocation;
  const _AllocationRow({required this.allocation});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.receipt_long_outlined,
        color: AppColors.primaryBlue,
        size: 20,
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VTA-${allocation.folio.toString().padLeft(6, '0')}',
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Saldo ${_money(allocation.previousBalance)} → ${_money(allocation.resultingBalance)}',
              style: const TextStyle(color: AppColors.textGrey, fontSize: 9.5),
            ),
          ],
        ),
      ),
      Text(
        _money(allocation.appliedAmount),
        style: const TextStyle(
          color: AppColors.primaryBlue,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _TotalRow({
    required this.label,
    required this.value,
    this.color = AppColors.navy,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 11.5),
        ),
      ),
      Text(
        _money(value),
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
