import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_history_item.dart';
import 'package:kommerze_mobile/features/sales_history/presentation/controllers/sales_history_controller.dart';

enum _CreditFilter { all, cash, credit }

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  final _searchController = TextEditingController();
  _CreditFilter _filter = _CreditFilter.all;
  DateTime? _selectedDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(salesHistoryProvider);
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Historial de ventas',
            subtitle: 'Consulta las ventas guardadas en este dispositivo',
            height: 174 + MediaQuery.paddingOf(context).top,
            showBackButton: true,
            content: _HeaderFilters(
              controller: _searchController,
              selectedDate: _selectedDate,
              onChanged: () => setState(() {}),
              onDatePressed: _chooseDate,
            ),
          ),
          Expanded(
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(salesHistoryProvider),
              ),
              data: (items) {
                final filtered = _filterItems(items);
                final dateItems = items
                    .where(
                      (item) =>
                          _selectedDate == null ||
                          _sameDay(item.date, _selectedDate!),
                    )
                    .toList(growable: false);
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(salesHistoryProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _SummaryGrid(
                        summary: SalesHistorySummary.fromItems(dateItems),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Ventas registradas',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_selectedDate != null) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 7),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _shortDate(_selectedDate!),
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          PopupMenuButton<_CreditFilter>(
                            initialValue: _filter,
                            onSelected: (value) =>
                                setState(() => _filter = value),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: _CreditFilter.all,
                                child: Text('Todas'),
                              ),
                              PopupMenuItem(
                                value: _CreditFilter.cash,
                                child: Text('Contado'),
                              ),
                              PopupMenuItem(
                                value: _CreditFilter.credit,
                                child: Text('Crédito'),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderGrey),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.tune_rounded,
                                    color: AppColors.primaryBlue,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _filterLabel,
                                    style: const TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      if (filtered.isEmpty)
                        const _EmptyState()
                      else
                        for (final item in filtered) ...[
                          _SaleCard(item: item),
                          const SizedBox(height: 9),
                        ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<SaleHistoryItem> _filterItems(List<SaleHistoryItem> items) {
    final normalized = _searchController.text.trim().toLowerCase();
    return items
        .where((item) {
          final matchesType = switch (_filter) {
            _CreditFilter.all => true,
            _CreditFilter.cash => !item.isCredit,
            _CreditFilter.credit => item.isCredit,
          };
          final matchesQuery =
              normalized.isEmpty ||
              item.clientName.toLowerCase().contains(normalized) ||
              item.formattedFolio.toLowerCase().contains(normalized) ||
              item.folio.toString().contains(normalized);
          final matchesDate =
              _selectedDate == null || _sameDay(item.date, _selectedDate!);
          return matchesType && matchesQuery && matchesDate;
        })
        .toList(growable: false);
  }

  String get _filterLabel => switch (_filter) {
    _CreditFilter.all => 'Todas',
    _CreditFilter.cash => 'Contado',
    _CreditFilter.credit => 'Crédito',
  };

  Future<void> _chooseDate() async {
    var draft = _selectedDate ?? DateTime.now();
    final selection = await showModalBottomSheet<_DateSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => FractionallySizedBox(
        heightFactor: .82,
        child: StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              children: [
                const Text(
                  'Seleccionar fecha de venta',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: SingleChildScrollView(
                    child: CalendarDatePicker(
                      initialDate: draft,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      onDateChanged: (value) =>
                          setModalState(() => draft = value),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(
                          context,
                          const _DateSelection(clear: true),
                        ),
                        child: const Text('Todas las fechas'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.pop(context, _DateSelection(date: draft)),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _selectedDate = selection.clear ? null : selection.date;
    });
  }
}

class _DateSelection {
  final DateTime? date;
  final bool clear;
  const _DateSelection({this.date, this.clear = false});
}

class _HeaderFilters extends StatelessWidget {
  final TextEditingController controller;
  final DateTime? selectedDate;
  final VoidCallback onChanged;
  final VoidCallback onDatePressed;
  const _HeaderFilters({
    required this.controller,
    required this.selectedDate,
    required this.onChanged,
    required this.onDatePressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            style: const TextStyle(color: AppColors.navy, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar por folio o cliente...',
              hintStyle: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12.5,
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged();
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
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Material(
          color: selectedDate == null ? Colors.white : AppColors.primarySurface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onDatePressed,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.calendar_month_outlined,
                color: selectedDate == null
                    ? AppColors.navy
                    : AppColors.primaryBlue,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SummaryGrid extends StatelessWidget {
  final SalesHistorySummary summary;
  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 9,
    crossAxisSpacing: 9,
    childAspectRatio: 1.85,
    children: [
      _SummaryCard(
        icon: Icons.shopping_bag_outlined,
        label: 'Total vendido',
        value: _money(summary.total),
        color: AppColors.primaryBlue,
      ),
      _SummaryCard(
        icon: Icons.receipt_long_outlined,
        label: 'Ventas',
        value: '${summary.sales}',
        color: const Color(0xFF7138C8),
      ),
      _SummaryCard(
        icon: Icons.payments_outlined,
        label: 'Contado',
        value: _money(summary.cashTotal),
        color: AppColors.success,
      ),
      _SummaryCard(
        icon: Icons.schedule_rounded,
        label: 'Crédito',
        value: _money(summary.creditTotal),
        color: const Color(0xFFE66A16),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textGrey, fontSize: 10),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SaleCard extends StatelessWidget {
  final SaleHistoryItem item;
  const _SaleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPending = item.statusName.toLowerCase() == 'pendiente';
    final statusColor = isPending ? const Color(0xFFE66A16) : AppColors.success;
    final itemColor = _itemColors[item.folio % _itemColors.length];
    return GestureDetector(
      onTap: () => context.push(
        AppConstants.saleDetailScreenRoute.replaceFirst(
          ':orderGuid',
          item.orderGuid,
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                color: itemColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Folio: ${item.formattedFolio}',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_date(item.date)}  •  ${_quantity(item.units)} artículos',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    item.statusName,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(item.total),
                  style: TextStyle(
                    color: item.isCredit
                        ? const Color(0xFFE66A16)
                        : AppColors.success,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _paymentIcon(item),
                        color: AppColors.primaryBlue,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.paymentLabel,
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Column(
      children: [
        Icon(Icons.receipt_long_outlined, color: AppColors.textGrey, size: 38),
        SizedBox(height: 10),
        Text(
          'No encontramos ventas',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 4),
        Text(
          'Las ventas guardadas aparecerán en este historial.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGrey, fontSize: 11.5),
        ),
      ],
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
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

String _money(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '\$${buffer.toString()}.${parts.last}';
}

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

const _itemColors = [
  AppColors.primaryBlue,
  Color(0xFF7138C8),
  Color(0xFFE66A16),
  AppColors.success,
  Color(0xFFE33B6A),
];

String _date(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final period = date.hour < 12 ? 'a.m.' : 'p.m.';
  return '${date.day} ${_months[date.month - 1]} ${date.year} '
      '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
}

String _shortDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

IconData _paymentIcon(SaleHistoryItem item) {
  if (item.paymentForms.length > 1) {
    return Icons.account_balance_wallet_outlined;
  }
  if (item.paymentForms.isEmpty) {
    return item.isCredit ? Icons.schedule_rounded : Icons.money_off_rounded;
  }
  return switch (item.paymentForms.first.key) {
    '01' => Icons.payments_outlined,
    '02' => Icons.receipt_long_outlined,
    '03' => Icons.account_balance_outlined,
    '04' || '28' || '29' => Icons.credit_card_outlined,
    '99' when item.isCredit => Icons.schedule_rounded,
    _ => Icons.account_balance_wallet_outlined,
  };
}

String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
