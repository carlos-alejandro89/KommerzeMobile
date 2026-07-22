import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/collections/data/repositories/collections_repository.dart';
import 'package:kommerze_mobile/features/collections/domain/entities/collection_models.dart';
import 'package:kommerze_mobile/features/collections/presentation/controllers/collections_controller.dart';
import 'package:kommerze_mobile/features/collections/presentation/widgets/cancel_collection_sheet.dart';

class CollectionClientScreen extends ConsumerWidget {
  final String clientGuid;

  const CollectionClientScreen({super.key, required this.clientGuid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionClientDetailProvider(clientGuid));
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: state.when(
        loading: () => Column(
          children: [
            AppHeader(
              title: 'Cobranza',
              showBackButton: true,
              onBack: context.pop,
            ),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
        error: (error, _) => Column(
          children: [
            AppHeader(
              title: 'Cobranza',
              showBackButton: true,
              onBack: context.pop,
            ),
            Expanded(child: Center(child: Text(error.toString()))),
          ],
        ),
        data: (detail) => _body(context, ref, detail),
      ),
      floatingActionButton: (state.value?.client.balance ?? 0) > .001
          ? FloatingActionButton.extended(
              onPressed: () => _register(context, ref),
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 1,
              icon: const Icon(Icons.payments_outlined, size: 20),
              label: const Text('Registrar cobro'),
            )
          : null,
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    CollectionClientDetail detail,
  ) {
    final client = detail.client;
    return Column(
      children: [
        AppHeader(
          title: 'Estado de cuenta',
          subtitle: client.name,
          height: 188 + MediaQuery.paddingOf(context).top,
          showBackButton: true,
          onBack: context.pop,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderValue(
                    label: 'Saldo pendiente',
                    value: _money(client.balance),
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                Expanded(
                  child: _HeaderValue(
                    label: 'Saldo vencido',
                    value: _money(client.overdueBalance),
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                Expanded(
                  child: _HeaderValue(
                    label: 'Crédito disponible',
                    value: _money(client.availableCredit),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(collectionClientDetailProvider(clientGuid));
              ref.invalidate(collectionsDashboardProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
              children: [
                _ClientIdentity(client: client),
                const SizedBox(height: 18),
                _SectionTitle(
                  title: 'Movimientos del estado de cuenta',
                  trailing: '${detail.statement.length}',
                ),
                const SizedBox(height: 9),
                if (detail.statement.isEmpty)
                  const _EmptyCard(text: 'No hay movimientos registrados.')
                else
                  _StatementCard(movements: detail.statement),
                const SizedBox(height: 18),
                _SectionTitle(
                  title: 'Cuentas pendientes',
                  trailing: '${detail.accounts.length}',
                ),
                const SizedBox(height: 9),
                if (detail.accounts.isEmpty)
                  const _EmptyCard(text: 'Este cliente no tiene adeudos.')
                else
                  for (final account in detail.accounts) ...[
                    _AccountCard(
                      account: account,
                      onOpenSale: () => context.push(
                        AppConstants.saleDetailScreenRoute.replaceFirst(
                          ':orderGuid',
                          account.orderGuid,
                        ),
                      ),
                      onToggleBlock: () => _toggleBlock(context, ref, account),
                    ),
                    const SizedBox(height: 9),
                  ],
                const SizedBox(height: 14),
                _SectionTitle(
                  title: 'Historial de cobros',
                  trailing: '${detail.collections.length}',
                ),
                const SizedBox(height: 9),
                if (detail.collections.isEmpty)
                  const _EmptyCard(text: 'Todavía no se han registrado cobros.')
                else
                  for (final collection in detail.collections) ...[
                    _CollectionCard(
                      collection: collection,
                      onCancel: collection.cancelled
                          ? null
                          : () => _cancelCollection(context, ref, collection),
                    ),
                    const SizedBox(height: 9),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final saved = await context.push<bool>(
      AppConstants.collectionRegisterScreenRoute.replaceFirst(
        ':clientGuid',
        clientGuid,
      ),
    );
    if (saved == true) {
      ref.invalidate(collectionClientDetailProvider(clientGuid));
      ref.invalidate(collectionsDashboardProvider);
    }
  }

  Future<void> _toggleBlock(
    BuildContext context,
    WidgetRef ref,
    ReceivableAccount account,
  ) async {
    try {
      await ref
          .read(collectionsRepositoryProvider)
          .setAccountBlocked(account.accountGuid, !account.blocked);
      ref.invalidate(collectionClientDetailProvider(clientGuid));
    } catch (error) {
      if (context.mounted) _message(context, error.toString(), false);
    }
  }

  Future<void> _cancelCollection(
    BuildContext context,
    WidgetRef ref,
    CollectionRecord collection,
  ) async {
    final cancellationReason = await showCancelCollectionSheet(context);
    if (cancellationReason == null || !context.mounted) return;
    try {
      await ref
          .read(collectionsRepositoryProvider)
          .cancelCollection(collection.collectionGuid, cancellationReason);
      ref.invalidate(collectionClientDetailProvider(clientGuid));
      ref.invalidate(collectionsDashboardProvider);
      if (context.mounted) {
        _message(context, 'Cobro cancelado y saldos restaurados.', true);
      }
    } catch (error) {
      if (context.mounted) _message(context, error.toString(), false);
    }
  }
}

class _HeaderValue extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderValue({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 8.5),
        ),
      ],
    ),
  );
}

class _ClientIdentity extends StatelessWidget {
  final CollectionClientSummary client;
  const _ClientIdentity({required this.client});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primaryLight,
          child: Icon(Icons.person_outline, color: AppColors.primaryBlue),
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
              const SizedBox(height: 3),
              Text(
                'RFC ${client.rfc}${client.phone.isEmpty ? '' : ' · ${client.phone}'}',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
              ),
              if (client.creditBalance > .001) ...[
                const SizedBox(height: 4),
                Text(
                  'Saldo a favor ${_money(client.creditBalance)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String trailing;
  const _SectionTitle({required this.title, required this.trailing});
  @override
  Widget build(BuildContext context) => Row(
    children: [
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
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          trailing,
          style: const TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _StatementCard extends StatelessWidget {
  final List<AccountStatementMovement> movements;
  const _StatementCard({required this.movements});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        for (var index = 0; index < movements.length; index++) ...[
          _StatementRow(movement: movements[index]),
          if (index < movements.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _StatementRow extends StatelessWidget {
  final AccountStatementMovement movement;
  const _StatementRow({required this.movement});
  @override
  Widget build(BuildContext context) {
    final charge = movement.type == AccountStatementMovementType.charge;
    final canOpenSale = charge && (movement.orderGuid?.isNotEmpty ?? false);
    return InkWell(
      onTap: canOpenSale
          ? () => context.push(
              AppConstants.saleDetailScreenRoute.replaceFirst(
                ':orderGuid',
                movement.orderGuid!,
              ),
            )
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: charge ? const Color(0xFFFFF1E8) : AppColors.successSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                charge ? Icons.add_rounded : Icons.remove_rounded,
                color: charge ? const Color(0xFFE66A16) : AppColors.success,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.description,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'dd MMM yyyy · hh:mm a',
                      'es_MX',
                    ).format(movement.date).toLowerCase(),
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${charge ? '+' : '−'}${_money(movement.amount)}',
                  style: TextStyle(
                    color: charge ? const Color(0xFFE66A16) : AppColors.success,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Saldo ${_money(movement.runningBalance)}',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            if (canOpenSale) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryBlue,
                size: 19,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final ReceivableAccount account;
  final VoidCallback onOpenSale;
  final VoidCallback onToggleBlock;
  const _AccountCard({
    required this.account,
    required this.onOpenSale,
    required this.onToggleBlock,
  });
  @override
  Widget build(BuildContext context) {
    final overdue = account.isOverdue;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: overdue ? const Color(0xFFFFEEDF) : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              account.blocked
                  ? Icons.lock_outline
                  : Icons.receipt_long_outlined,
              color: overdue ? const Color(0xFFE66A16) : AppColors.primaryBlue,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: InkWell(
              onTap: onOpenSale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Venta VTA-${account.folio.toString().padLeft(6, '0')}',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Vence ${DateFormat('dd MMM yyyy', 'es_MX').format(account.dueAt)}',
                    style: TextStyle(
                      color: overdue
                          ? const Color(0xFFE66A16)
                          : AppColors.textGrey,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Original ${_money(account.originalAmount)} · Abonado ${_money(account.paidAmount)}',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(account.balance),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                account.blocked ? 'En aclaración' : account.status,
                style: TextStyle(
                  color: account.blocked
                      ? const Color(0xFFE66A16)
                      : AppColors.textGrey,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            color: Colors.white,
            onSelected: (_) => onToggleBlock(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      account.blocked ? Icons.lock_open : Icons.lock_outline,
                      color: AppColors.primaryBlue,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      account.blocked ? 'Desbloquear cuenta' : 'En aclaración',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final CollectionRecord collection;
  final VoidCallback? onCancel;
  const _CollectionCard({required this.collection, required this.onCancel});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: collection.cancelled
                    ? AppColors.errorSoft
                    : AppColors.successSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                collection.cancelled
                    ? Icons.money_off_rounded
                    : Icons.payments_outlined,
                color: collection.cancelled
                    ? AppColors.error
                    : AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat(
                      'dd MMM yyyy · hh:mm a',
                      'es_MX',
                    ).format(collection.date).toLowerCase(),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    collection.paymentForms.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Registró ${collection.userName}',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(collection.total),
                  style: TextStyle(
                    color: collection.cancelled
                        ? AppColors.error
                        : AppColors.success,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    decoration: collection.cancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  collection.cancelled
                      ? 'Cancelado'
                      : 'Aplicado ${_money(collection.applied)}',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
            if (onCancel != null)
              PopupMenuButton<String>(
                color: Colors.white,
                onSelected: (_) => onCancel!(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          color: AppColors.error,
                          size: 19,
                        ),
                        SizedBox(width: 9),
                        Text('Cancelar cobro'),
                      ],
                    ),
                  ),
                ],
              )
            else
              const SizedBox(width: 12),
          ],
        ),
        if (collection.appliedSales.isNotEmpty) ...[
          const Divider(height: 17),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 6, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                collection.appliedSales.length == 1
                    ? 'Aplicado a la venta'
                    : 'Aplicado a ${collection.appliedSales.length} ventas',
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          for (final sale in collection.appliedSales)
            _AppliedSaleRow(sale: sale),
        ],
      ],
    ),
  );
}

class _AppliedSaleRow extends StatelessWidget {
  final CollectionAppliedSale sale;

  const _AppliedSaleRow({required this.sale});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: sale.orderGuid.isEmpty
        ? null
        : () => context.push(
            AppConstants.saleDetailScreenRoute.replaceFirst(
              ':orderGuid',
              sale.orderGuid,
            ),
          ),
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.primaryBlue,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Venta VTA-${sale.folio.toString().padLeft(6, '0')}',
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _money(sale.appliedAmount),
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.primaryBlue,
            size: 19,
          ),
        ],
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration(),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
    ),
  );
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(15),
  border: Border.all(color: AppColors.borderGrey.withValues(alpha: .7)),
  boxShadow: [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: .035),
      blurRadius: 11,
      offset: const Offset(0, 4),
    ),
  ],
);

void _message(BuildContext context, String message, bool success) {
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

String _money(double value) => '\$${value.toStringAsFixed(2)}';
