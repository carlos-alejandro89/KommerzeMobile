import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/reports/data/datasources/profit_report_local_data_source.dart';
import 'package:kommerze_mobile/features/reports/data/services/profit_report_pdf_service.dart';
import 'package:kommerze_mobile/features/reports/domain/entities/profit_report.dart';

class ProfitReportDetailScreen extends ConsumerWidget {
  final String operationGuid;
  const ProfitReportDetailScreen({super.key, required this.operationGuid});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: AppColors.lightBackground,
    body: FutureBuilder<ProfitOperationDetail>(
      future: ref
          .read(profitReportLocalDataSourceProvider)
          .getDetail(operationGuid),
      builder: (context, snapshot) {
        final detail = snapshot.data;
        return Column(
          children: [
            AppHeader(
              title: 'Detalle de utilidad',
              subtitle: detail == null
                  ? 'Operación de sucursal'
                  : detail.operation.branchName,
              height: 112 + MediaQuery.paddingOf(context).top,
              showBackButton: true,
              onBack: context.pop,
              actions: [
                IconButton(
                  tooltip: 'Compartir PDF',
                  onPressed: detail == null
                      ? null
                      : () => _share(context, detail),
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                ),
              ],
            ),
            Expanded(
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                  ? Center(child: Text(snapshot.error.toString()))
                  : _Content(detail: detail!),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _share(
    BuildContext context,
    ProfitOperationDetail detail,
  ) async {
    try {
      await ProfitReportPdfService.share(detail);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible compartir el PDF: $error')),
      );
    }
  }
}

class _Content extends StatelessWidget {
  final ProfitOperationDetail detail;
  const _Content({required this.detail});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
    children: [
      _OperationHeader(operation: detail.operation),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _Metric(
              label: 'Venta neta',
              value: _money(detail.operation.netSales),
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Metric(
              label: 'Costo',
              value: _money(detail.operation.cost),
              color: const Color(0xFFE58A18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Metric(
              label: 'Utilidad',
              value: _money(detail.operation.profit),
              color: const Color(0xFF15966A),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF15966A).withValues(alpha: .09),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.percent_rounded,
              color: Color(0xFF15966A),
              size: 20,
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Margen de utilidad',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _percent(detail.operation.profitMargin),
              style: const TextStyle(
                color: Color(0xFF15966A),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 19),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Ventas de la operación',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${detail.sales.length}',
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (detail.sales.isEmpty)
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Esta operación no tiene ventas registradas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey),
          ),
        )
      else
        for (final sale in detail.sales) ...[
          _SaleCard(sale: sale),
          const SizedBox(height: 9),
        ],
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () => ProfitReportPdfService.share(detail),
        icon: const Icon(Icons.share_rounded),
        label: const Text('Compartir reporte PDF'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ],
  );
}

class _OperationHeader extends StatelessWidget {
  final ProfitOperationSummary operation;
  const _OperationHeader({required this.operation});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                operation.branchName,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Inicio ${_date(operation.startedAt)}',
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 10.5,
                ),
              ),
              Text(
                operation.endedAt == null
                    ? 'Operación en curso'
                    : 'Cierre ${_date(operation.endedAt!)}',
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 10.5,
                ),
              ),
              Text(
                'Apertura: ${operation.openedBy}',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 9.5),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SaleCard extends StatelessWidget {
  final ProfitSaleItem sale;
  const _SaleCard({required this.sale});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: () => context.push(
        AppConstants.saleDetailScreenRoute.replaceFirst(
          ':orderGuid',
          sale.orderGuid,
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF15966A).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Color(0xFF15966A),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.formattedFolio,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    sale.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 10.5,
                    ),
                  ),
                  Text(
                    DateFormat(
                      "d MMM yyyy · h:mm a",
                      'es_MX',
                    ).format(sale.date),
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
                  _money(sale.profit),
                  style: const TextStyle(
                    color: Color(0xFF15966A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${_percent(sale.profitMargin)} margen',
                  style: const TextStyle(
                    color: Color(0xFF15966A),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_money(sale.net)} venta',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 9,
                  ),
                ),
                if (sale.discount > .001)
                  Text(
                    '-${_money(sale.discount)} desc.',
                    style: const TextStyle(
                      color: Color(0xFFE66A16),
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primaryBlue,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

String _money(double value) =>
    NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(value);
String _date(DateTime value) =>
    DateFormat("d MMM yyyy · h:mm a", 'es_MX').format(value);
String _percent(double value) => '${value.toStringAsFixed(1)}%';
