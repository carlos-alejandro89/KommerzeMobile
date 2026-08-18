import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/loans/domain/entities/customer_loan.dart';
import 'package:kommerze_mobile/features/loans/data/repositories/loans_repository.dart';
import 'package:kommerze_mobile/features/loans/presentation/controllers/loans_controller.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loansProvider);
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Préstamos',
            subtitle: 'Efectivo entregado a clientes',
            height: 112 + MediaQuery.paddingOf(context).top,
            showBackButton: true,
            onBack: context.pop,
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (loans) => _LoansContent(
                loans: loans,
                onRefresh: () async {
                  await ref
                      .read(loansRepositoryProvider)
                      .recoverByActiveBranch();
                  ref.invalidate(loansProvider);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await context.push<bool>(AppConstants.loanFormRoute);
          if (saved == true) ref.invalidate(loansProvider);
        },
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo préstamo'),
      ),
    );
  }
}

class _LoansContent extends StatelessWidget {
  final List<CustomerLoan> loans;
  final Future<void> Function() onRefresh;
  const _LoansContent({required this.loans, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final active = loans.where((loan) => !loan.isPaid).toList();
    final balance = active.fold<double>(0, (sum, loan) => sum + loan.balance);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: _Summary(
                  icon: Icons.payments_outlined,
                  label: 'Saldo prestado',
                  value: _money(balance),
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Summary(
                  icon: Icons.people_outline_rounded,
                  label: 'Préstamos activos',
                  value: '${active.length}',
                  color: const Color(0xFF7138C8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Historial de préstamos',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (loans.isEmpty)
            const _EmptyLoans()
          else
            for (final loan in loans) ...[
              _LoanCard(loan: loan),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Summary({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _LoanCard extends StatelessWidget {
  final CustomerLoan loan;
  const _LoanCard({required this.loan});
  @override
  Widget build(BuildContext context) {
    final color = loan.isPaid
        ? AppColors.success
        : loan.isOverdue
        ? const Color(0xFFE66A16)
        : AppColors.primaryBlue;
    final status = loan.isPaid
        ? 'Liquidado'
        : loan.isOverdue
        ? 'Vencido'
        : 'Pendiente';
    return InkWell(
      onTap: () => context.push(
        AppConstants.collectionClientScreenRoute.replaceFirst(
          ':clientGuid',
          loan.clientGuid,
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.payments_outlined, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.clientName,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loan.concept.isEmpty
                        ? 'Préstamo en efectivo'
                        : loan.concept,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 10.5,
                    ),
                  ),
                  Text(
                    'Vence ${DateFormat('dd MMM yyyy', 'es_MX').format(loan.dueDate)}',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(loan.balance),
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLoans extends StatelessWidget {
  const _EmptyLoans();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Column(
      children: [
        Icon(Icons.payments_outlined, color: AppColors.primaryBlue, size: 40),
        SizedBox(height: 10),
        Text(
          'Aún no hay préstamos registrados.',
          style: TextStyle(color: AppColors.textGrey),
        ),
      ],
    ),
  );
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';
