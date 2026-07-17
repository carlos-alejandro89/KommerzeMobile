import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/core/widgets/product_image.dart';
import 'package:kommerze_mobile/features/sales_history/data/services/sale_receipt_pdf_service.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_detail.dart';
import 'package:kommerze_mobile/features/sales_history/presentation/controllers/sales_history_controller.dart';

class SaleDetailScreen extends ConsumerWidget {
  final String orderGuid;
  const SaleDetailScreen({super.key, required this.orderGuid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleDetailProvider(orderGuid));
    final sale = state.value;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Detalle de venta',
            subtitle: 'Consulta la información completa de la venta',
            height: 108,
            showBackButton: true,
            actions: [
              IconButton(
                tooltip: 'Imprimir comprobante',
                onPressed: sale == null ? null : () => _print(context, sale),
                icon: const Icon(
                  Icons.print_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              PopupMenuButton<String>(
                iconColor: Colors.white,
                onSelected: sale == null
                    ? null
                    : (value) {
                        if (value == 'send') _share(context, sale);
                      },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'send',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.share_outlined),
                      title: Text('Compartir comprobante'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorDetail(
                message: error.toString(),
                onRetry: () => ref.invalidate(saleDetailProvider(orderGuid)),
              ),
              data: (sale) => sale == null
                  ? const Center(child: Text('La venta ya no está disponible.'))
                  : _DetailContent(
                      sale: sale,
                      onPrint: () => _print(context, sale),
                      onShare: () => _share(context, sale),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _print(BuildContext context, SaleDetail sale) async {
    try {
      await SaleReceiptPdfService.printReceipt(sale);
    } catch (error) {
      if (context.mounted) _message(context, error.toString());
    }
  }

  Future<void> _share(BuildContext context, SaleDetail sale) async {
    try {
      await SaleReceiptPdfService.shareReceipt(sale);
    } catch (error) {
      if (context.mounted) _message(context, error.toString());
    }
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final SaleDetail sale;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  const _DetailContent({
    required this.sale,
    required this.onPrint,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
    children: [
      _SaleHero(sale: sale),
      const SizedBox(height: 12),
      _Section(
        title: 'Información general',
        icon: Icons.description_outlined,
        child: LayoutBuilder(
          builder: (_, constraints) {
            final values = [
              ('Cliente', sale.clientName),
              ('RFC', sale.clientRfc.isEmpty ? 'Sin RFC' : sale.clientRfc),
              ('Fecha y hora', _date(sale.date)),
              ('Sucursal', sale.branchName),
              ('Tipo de pedido', sale.orderTypeName),
              ('Modalidad', sale.isCredit ? 'Crédito' : 'Contado'),
            ];
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 13,
              children: [
                for (final value in values)
                  SizedBox(
                    width: width,
                    child: _Information(label: value.$1, value: value.$2),
                  ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      _Section(
        title: 'Artículos vendidos',
        icon: Icons.shopping_bag_outlined,
        trailing: _CountBadge('${sale.items.length} artículos'),
        child: Column(
          children: [
            for (var index = 0; index < sale.items.length; index++) ...[
              _ItemTile(item: sale.items[index]),
              if (index < sale.items.length - 1) const Divider(height: 18),
            ],
            const Divider(height: 22),
            _AmountRow(label: 'Subtotal', value: sale.subtotal),
            if (sale.discount > 0)
              _AmountRow(label: 'Descuento', value: -sale.discount),
            const SizedBox(height: 6),
            _AmountRow(label: 'Total', value: sale.total, emphasized: true),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Section(
        title: 'Pagos realizados',
        icon: Icons.account_balance_wallet_outlined,
        trailing: _CountBadge('${sale.payments.length} pagos'),
        child: Column(
          children: [
            if (sale.payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No existen pagos registrados.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                ),
              )
            else
              for (var index = 0; index < sale.payments.length; index++) ...[
                _PaymentTile(payment: sale.payments[index]),
                if (index < sale.payments.length - 1) const Divider(height: 16),
              ],
            const Divider(height: 20),
            _AmountRow(label: 'Total pagado', value: sale.paid),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartir'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: onPrint,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimir'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _SaleHero extends StatelessWidget {
  final SaleDetail sale;
  const _SaleHero({required this.sale});
  @override
  Widget build(BuildContext context) {
    final pending = sale.statusName.toLowerCase() == 'pendiente';
    final color = pending ? const Color(0xFFE66A16) : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_cart_outlined, color: color, size: 27),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Folio',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 10.5),
                ),
                Text(
                  sale.formattedFolio,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sale.statusName,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Total',
                style: TextStyle(color: AppColors.textGrey, fontSize: 10.5),
              ),
              Text(
                _money(sale.total),
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sale.payments.length > 1
                    ? 'Multipago'
                    : sale.payments.isEmpty
                    ? 'Sin pago'
                    : sale.payments.first.label,
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
            Icon(icon, color: AppColors.primaryBlue, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _Information extends StatelessWidget {
  final String label;
  final String value;
  const _Information({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textGrey, fontSize: 10),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _ItemTile extends StatelessWidget {
  final SaleDetailItem item;
  const _ItemTile({required this.item});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(9),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ProductImage(imagePath: item.imagePath, iconSize: 19),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.barcode.isEmpty ? item.code : item.barcode,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 9.5),
            ),
          ],
        ),
      ),
      Text(
        '${_money(item.unitPrice)} × ${_quantity(item.quantity)}',
        style: const TextStyle(color: AppColors.textGrey, fontSize: 10.5),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 62,
        child: Text(
          _money(item.total),
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _PaymentTile extends StatelessWidget {
  final SaleDetailPayment payment;
  const _PaymentTile({required this.payment});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          _paymentIcon(payment.paymentFormKey),
          color: AppColors.success,
          size: 19,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              payment.label,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _date(payment.paidAt),
              style: const TextStyle(color: AppColors.textGrey, fontSize: 9.5),
            ),
          ],
        ),
      ),
      Text(
        _money(payment.amount),
        style: const TextStyle(
          color: AppColors.success,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasized;
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: emphasized ? 13 : 11,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          _money(value),
          style: TextStyle(
            color: emphasized ? AppColors.primaryBlue : AppColors.navy,
            fontSize: emphasized ? 17 : 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _CountBadge extends StatelessWidget {
  final String label;
  const _CountBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.primaryBlue,
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ErrorDetail extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorDetail({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

IconData _paymentIcon(String key) => switch (key) {
  '01' => Icons.payments_outlined,
  '02' => Icons.receipt_long_outlined,
  '03' => Icons.account_balance_outlined,
  '04' || '28' || '29' => Icons.credit_card_outlined,
  _ => Icons.account_balance_wallet_outlined,
};

String _money(double value) => '\$${value.toStringAsFixed(2)}';
String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

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

String _date(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final period = date.hour < 12 ? 'a.m.' : 'p.m.';
  return '${date.day} ${_months[date.month - 1]} ${date.year} '
      '${hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')} $period';
}
