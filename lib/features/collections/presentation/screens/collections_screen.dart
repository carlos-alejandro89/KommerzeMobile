import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/collections/domain/entities/collection_models.dart';
import 'package:kommerze_mobile/features/collections/presentation/controllers/collections_controller.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionsDashboardProvider);
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Cobranza',
            subtitle: 'Cuentas por cobrar y abonos de clientes',
            height: 174 + MediaQuery.paddingOf(context).top,
            showBackButton: true,
            onBack: context.pop,
            content: SizedBox(
              height: 48,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.navy, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar cliente, RFC o teléfono...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: state.when(
              data: _content,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(collectionsDashboardProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(CollectionDashboard dashboard) {
    final query = _search.text.trim().toLowerCase();
    final clients = dashboard.clients
        .where((client) {
          return query.isEmpty ||
              client.name.toLowerCase().contains(query) ||
              client.rfc.toLowerCase().contains(query) ||
              client.phone.toLowerCase().contains(query);
        })
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(collectionsDashboardProvider),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final width = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SummaryCard(
                        width: width,
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Saldo por cobrar',
                        value: _money(dashboard.totalReceivable),
                        color: AppColors.primaryBlue,
                      ),
                      _SummaryCard(
                        width: width,
                        icon: Icons.warning_amber_rounded,
                        title: 'Saldo vencido',
                        value: _money(dashboard.overdueReceivable),
                        color: const Color(0xFFE66A16),
                      ),
                      _SummaryCard(
                        width: width,
                        icon: Icons.groups_outlined,
                        title: 'Clientes con saldo',
                        value: '${dashboard.clients.length}',
                        color: const Color(0xFF7138C8),
                      ),
                      _SummaryCard(
                        width: width,
                        icon: Icons.payments_outlined,
                        title: 'Cobrado hoy',
                        value: _money(dashboard.collectedToday),
                        color: AppColors.success,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Clientes con cuentas pendientes',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (clients.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.separated(
                itemCount: clients.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _ClientDebtCard(
                  client: clients[index],
                  onTap: () async {
                    await context.push(
                      AppConstants.collectionClientScreenRoute.replaceFirst(
                        ':clientGuid',
                        clients[index].clientGuid,
                      ),
                    );
                    ref.invalidate(collectionsDashboardProvider);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 94,
    padding: const EdgeInsets.all(12),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ClientDebtCard extends StatelessWidget {
  final CollectionClientSummary client;
  final VoidCallback onTap;

  const _ClientDebtCard({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final overdue = client.overdueBalance > .001;
    final initials = client.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: overdue
                    ? const Color(0xFFFFEEDF)
                    : AppColors.primaryLight,
                child: Text(
                  initials.isEmpty ? 'C' : initials,
                  style: TextStyle(
                    color: overdue
                        ? const Color(0xFFE66A16)
                        : AppColors.primaryBlue,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${client.openAccounts} ${client.openAccounts == 1 ? 'cuenta' : 'cuentas'} · ${client.rfc}',
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11,
                      ),
                    ),
                    if (client.oldestDueDate != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${overdue ? 'Vencida desde' : 'Próximo vencimiento'} ${DateFormat('dd MMM yyyy', 'es_MX').format(client.oldestDueDate!)}',
                        style: TextStyle(
                          color: overdue
                              ? const Color(0xFFE66A16)
                              : AppColors.textGrey,
                          fontSize: 10.5,
                          fontWeight: overdue
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(client.balance),
                    style: TextStyle(
                      color: overdue ? const Color(0xFFE66A16) : AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Saldo pendiente',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 9.5),
                  ),
                  const SizedBox(height: 5),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primaryBlue,
                    size: 21,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt_rounded, color: AppColors.success, size: 52),
          SizedBox(height: 12),
          Text(
            'No hay cuentas pendientes',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Las ventas a crédito aparecerán aquí.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 42),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.borderGrey.withValues(alpha: .7)),
  boxShadow: [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: .04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);

String _money(double value) => '\$${value.toStringAsFixed(2)}';
