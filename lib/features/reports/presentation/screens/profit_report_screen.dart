import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/reports/data/datasources/profit_report_local_data_source.dart';
import 'package:kommerze_mobile/features/reports/domain/entities/profit_report.dart';

class ProfitReportScreen extends ConsumerStatefulWidget {
  const ProfitReportScreen({super.key});
  @override
  ConsumerState<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends ConsumerState<ProfitReportScreen> {
  DateTime? _date;
  late Future<List<ProfitOperationSummary>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = ref
      .read(profitReportLocalDataSourceProvider)
      .getOperations(_date);

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('es', 'MX'),
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected == null) return;
    setState(() {
      _date = selected;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.lightBackground,
    body: Column(
      children: [
        AppHeader(
          title: 'Reporte de utilidades',
          subtitle: 'Últimas 6 operaciones o todas desde una fecha inicial',
          height: 166 + MediaQuery.paddingOf(context).top,
          showBackButton: true,
          onBack: context.pop,
          content: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(13),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.primaryBlue,
                        size: 21,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _date == null
                            ? 'Todas las fechas'
                            : 'Desde ${DateFormat("d 'de' MMMM 'de' yyyy", 'es_MX').format(_date!)}',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_date != null)
                        IconButton(
                          tooltip: 'Quitar fecha inicial',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() {
                            _date = null;
                            _load();
                          }),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textGrey,
                            size: 19,
                          ),
                        )
                      else
                        const Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.textGrey,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ProfitOperationSummary>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _Message(
                  icon: Icons.error_outline,
                  text: snapshot.error.toString(),
                );
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const _Message(
                  icon: Icons.event_busy_outlined,
                  text: 'No hay operaciones desde la fecha seleccionada.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => setState(_load),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                  children: [
                    _DaySummary(items: items),
                    const SizedBox(height: 18),
                    const Text(
                      'Operaciones de sucursal',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final item in items) ...[
                      _OperationCard(
                        item: item,
                        onTap: () => context.push(
                          AppConstants.profitReportDetailRoute.replaceFirst(
                            ':operationGuid',
                            item.guid,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
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

class _DaySummary extends StatelessWidget {
  final List<ProfitOperationSummary> items;
  const _DaySummary({required this.items});
  @override
  Widget build(BuildContext context) {
    final sales = items.fold<double>(0, (s, e) => s + e.netSales);
    final profit = items.fold<double>(0, (s, e) => s + e.profit);
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'Venta neta',
            value: _money(sales),
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            label:
                'Utilidad · ${_percent(sales.abs() < .001 ? 0 : profit / sales * 100)}',
            value: _money(profit),
            color: const Color(0xFF15966A),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
        ),
        const SizedBox(height: 5),
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

class _OperationCard extends StatelessWidget {
  final ProfitOperationSummary item;
  final VoidCallback onTap;
  const _OperationCard({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.branchName,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${DateFormat('HH:mm').format(item.startedAt)} — ${item.endedAt == null ? 'En curso' : DateFormat('HH:mm').format(item.endedAt!)} · ${item.openedBy}',
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primaryBlue,
                ),
              ],
            ),
            const Divider(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Small(label: 'Ventas', value: '${item.salesCount}'),
                _Small(label: 'Venta neta', value: _money(item.netSales)),
                _Small(label: 'Costo', value: _money(item.cost)),
                _Small(
                  label: 'Utilidad · ${_percent(item.profitMargin)}',
                  value: _money(item.profit),
                  color: const Color(0xFF15966A),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Small extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Small({
    required this.label,
    required this.value,
    this.color = AppColors.navy,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textGrey, fontSize: 9),
      ),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textGrey, size: 42),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textGrey),
          ),
        ],
      ),
    ),
  );
}

String _money(double value) =>
    NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(value);
String _percent(double value) => '${value.toStringAsFixed(1)}%';
