import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/checkout/domain/entities/sale_payment.dart';
import 'package:kommerze_mobile/features/checkout/presentation/controllers/checkout_controller.dart';
import 'package:kommerze_mobile/features/checkout/presentation/widgets/add_payment_sheet.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:kommerze_mobile/features/sales/presentation/controllers/sales_controller.dart';
import 'package:kommerze_mobile/features/sales/data/repositories/sales_repository.dart';
import 'package:kommerze_mobile/features/sales_history/presentation/controllers/sales_history_controller.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_payment_draft.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_order.dart';
import 'package:kommerze_mobile/features/branch_operation/presentation/controllers/branch_operation_controller.dart';
import 'package:kommerze_mobile/features/inventory/presentation/controllers/inventory_controller.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkout = ref.watch(checkoutControllerProvider);
    final total = ref.watch(saleCartTotalProvider);
    final pending = (total - checkout.paid)
        .clamp(0, double.infinity)
        .toDouble();
    final change = (checkout.paid - total).clamp(0, double.infinity).toDouble();
    final appliedPaid = checkout.paid.clamp(0, total).toDouble();
    final covered = total > 0 && pending < .01;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          const AppHeader(
            title: 'Checkout',
            subtitle: 'Finaliza la venta y registra el pago',
            height: 106,
            showBackButton: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _Section(
                  title: 'Cliente de la venta',
                  icon: Icons.people_alt_outlined,
                  trailing: TextButton.icon(
                    onPressed: () => _selectClient(context, ref),
                    icon: Icon(
                      checkout.client == null
                          ? Icons.person_add_alt_1_rounded
                          : Icons.edit_outlined,
                      size: 18,
                    ),
                    label: Text(
                      checkout.client == null ? 'Seleccionar' : 'Cambiar',
                    ),
                  ),
                  child: checkout.client == null
                      ? _EmptyClient(onTap: () => _selectClient(context, ref))
                      : _SelectedClient(
                          client: checkout.client!,
                          onTap: () => _selectClient(context, ref),
                        ),
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Resumen de la venta',
                  icon: Icons.sell_outlined,
                  child: Row(
                    children: [
                      Expanded(
                        child: _Amount(
                          label: 'Total',
                          value: total,
                          color: AppColors.primaryBlue,
                          large: true,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _Amount(
                              label: 'Pagado',
                              value: appliedPaid,
                              color: AppColors.success,
                            ),
                            const SizedBox(height: 8),
                            change > .01
                                ? _Amount(
                                    label: 'Cambio',
                                    value: change,
                                    color: AppColors.primaryBlue,
                                  )
                                : _Amount(
                                    label: 'Por pagar',
                                    value: pending,
                                    color: pending > .01
                                        ? const Color(0xFFE66A16)
                                        : AppColors.success,
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Pagos agregados (${checkout.payments.length})',
                  icon: Icons.account_balance_wallet_outlined,
                  trailing: checkout.payments.isEmpty
                      ? null
                      : TextButton.icon(
                          onPressed: () => ref
                              .read(checkoutControllerProvider.notifier)
                              .clearPayments(),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          label: const Text(
                            'Limpiar',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                  child: Column(
                    children: [
                      if (checkout.payments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            'Agrega uno o varios métodos de pago.',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      for (final payment in checkout.payments)
                        _PaymentTile(
                          payment: payment,
                          onDelete: () => ref
                              .read(checkoutControllerProvider.notifier)
                              .removePayment(payment.id),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: pending > .01
                              ? () => _addPayment(
                                  context,
                                  ref,
                                  pending,
                                  checkout.client,
                                )
                              : null,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Agregar pago'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: pending > .01
                        ? const Color(0xFFFFF6E9)
                        : AppColors.successSoft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        change > .01
                            ? Icons.currency_exchange_rounded
                            : pending > .01
                            ? Icons.credit_card_rounded
                            : Icons.check_circle_outline_rounded,
                        color: change > .01
                            ? AppColors.primaryBlue
                            : pending > .01
                            ? const Color(0xFFE66A16)
                            : AppColors.success,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          change > .01
                              ? 'Cambio a entregar'
                              : pending > .01
                              ? 'Falta por cubrir'
                              : 'Pago cubierto',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _money(change > .01 ? change : pending),
                        style: TextStyle(
                          color: change > .01
                              ? AppColors.primaryBlue
                              : pending > .01
                              ? const Color(0xFFE66A16)
                              : AppColors.success,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE7ECF5))),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      !checkout.isSubmitting &&
                          checkout.client != null &&
                          total > 0
                      ? () => _saveSale(context, ref, statusName: 'Pendiente')
                      : null,
                  icon: checkout.isSubmitting
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.schedule_rounded),
                  label: Text(
                    checkout.isSubmitting ? 'Guardando...' : 'Pendiente',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed:
                      !checkout.isSubmitting &&
                          checkout.client != null &&
                          covered
                      ? () => _finish(context, ref)
                      : null,
                  icon: checkout.isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    checkout.isSubmitting
                        ? 'Generando venta...'
                        : 'Finalizar venta',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectClient(BuildContext context, WidgetRef ref) async {
    final client = await context.push<Client>(
      AppConstants.checkoutClientScreenRoute,
    );
    if (client != null) {
      ref.read(checkoutControllerProvider.notifier).selectClient(client);
    }
  }

  Future<void> _addPayment(
    BuildContext context,
    WidgetRef ref,
    double pending,
    Client? client,
  ) async {
    final draft = await AddPaymentSheet.show(
      context,
      pending: pending,
      availableCredit: client?.creditAmount ?? 0,
    );
    if (draft == null) return;
    ref
        .read(checkoutControllerProvider.notifier)
        .addPayment(
          method: draft.method,
          amount: draft.amount,
          reference: draft.reference,
        );
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    await _saveSale(context, ref, statusName: 'Confirmado');
  }

  Future<void> _saveSale(
    BuildContext context,
    WidgetRef ref, {
    required String statusName,
  }) async {
    final controller = ref.read(checkoutControllerProvider.notifier);
    if (ref.read(checkoutControllerProvider).isSubmitting) return;
    controller.setSubmitting(true);
    try {
      await _performSaveSale(context, ref, statusName: statusName);
    } finally {
      controller.setSubmitting(false);
    }
  }

  Future<void> _performSaveSale(
    BuildContext context,
    WidgetRef ref, {
    required String statusName,
  }) async {
    final checkout = ref.read(checkoutControllerProvider);
    final client = checkout.client;
    final cart = ref.read(saleCartControllerProvider);
    if (client == null || cart.isEmpty) return;
    late final SaleOrder order;
    try {
      order = await ref
          .read(salesRepositoryProvider)
          .save(
            clientGuid: client.guid,
            isCredit: checkout.payments.any(
              (payment) => payment.method == PaymentMethod.credit,
            ),
            items: cart,
            payments: [
              for (final payment in checkout.payments)
                SalePaymentDraft(
                  paymentFormKey: _paymentFormKey(payment.method),
                  amount: payment.amount,
                  isCredit: payment.method == PaymentMethod.credit,
                  paidAt: payment.createdAt,
                ),
            ],
            statusName: statusName,
          );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    SalesSyncReport? syncReport;
    try {
      syncReport = await ref.read(salesRepositoryProvider).syncPending();
    } catch (_) {
      // La venta ya está protegida en SQLite y se reintentará posteriormente.
    }
    if (!context.mounted) return;
    final synchronized = syncReport?.isSynchronized(order.orderGuid) ?? false;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          synchronized
              ? 'Venta sincronizada'
              : statusName == 'Confirmado'
              ? 'Venta guardada'
              : 'Venta pendiente',
        ),
        content: Text(
          synchronized
              ? 'La venta con folio ${order.folio} se registró en Kommerze Cloud.'
              : 'La venta con folio ${order.folio} se guardó localmente y quedó pendiente de sincronización.',
        ),
        actions: [
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    ref.read(saleCartControllerProvider.notifier).clear();
    ref.read(checkoutControllerProvider.notifier).reset();
    ref.invalidate(recentSalesProvider);
    ref.invalidate(salesHistoryProvider);
    ref.invalidate(inventoryControllerProvider);
    ref.invalidate(salesCatalogControllerProvider);
    ref.invalidate(branchOperationControllerProvider);
    if (context.mounted) context.go(AppConstants.welcomeScreenRoute);
  }
}

String _paymentFormKey(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => '01',
  PaymentMethod.check => '02',
  PaymentMethod.transfer => '03',
  PaymentMethod.card => '04',
  PaymentMethod.credit => '99',
  PaymentMethod.other => '99',
};

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 13),
        child,
      ],
    ),
  );
}

class _EmptyClient extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyClient({required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(13),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.person_search_outlined,
            color: AppColors.primaryBlue,
            size: 30,
          ),
          SizedBox(height: 7),
          Text(
            'Selecciona el cliente de esta venta',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
          ),
        ],
      ),
    ),
  );
}

class _SelectedClient extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;
  const _SelectedClient({required this.client, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.successSoft,
          child: Text(
            _initials(client.name),
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'RFC ${client.rfc}${client.phone.isEmpty ? '' : '  •  ${client.phone}'}',
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 11.5,
                ),
              ),
              if (client.creditAmount > 0)
                Text(
                  'Crédito disponible ${_money(client.creditAmount)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.primaryBlue),
      ],
    ),
  );
}

class _Amount extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool large;
  const _Amount({
    required this.label,
    required this.value,
    required this.color,
    this.large = false,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textGrey, fontSize: 11.5),
      ),
      const SizedBox(height: 4),
      FittedBox(
        child: Text(
          _money(value),
          style: TextStyle(
            color: color,
            fontSize: large ? 28 : 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _PaymentTile extends StatelessWidget {
  final SalePayment payment;
  final VoidCallback onDelete;
  const _PaymentTile({required this.payment, required this.onDelete});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(
            _paymentIcon(payment.method),
            color: AppColors.primaryBlue,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.method.label,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (payment.reference.isNotEmpty)
                  Text(
                    payment.reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _money(payment.amount),
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
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
String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
String _money(double value) => '\$${value.toStringAsFixed(2)}';
