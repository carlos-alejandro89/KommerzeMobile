import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/core/widgets/primary_button.dart';
import 'package:kommerze_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kommerze_mobile/features/branch_operation/domain/entities/branch_operation.dart';
import 'package:kommerze_mobile/features/branch_operation/domain/entities/branch_operation_state.dart';
import 'package:kommerze_mobile/features/branch_operation/presentation/controllers/branch_operation_controller.dart';
import 'package:kommerze_mobile/features/profile/presentation/controllers/profile_photo_controller.dart';

class BranchOperationScreen extends ConsumerStatefulWidget {
  const BranchOperationScreen({super.key});

  @override
  ConsumerState<BranchOperationScreen> createState() =>
      _BranchOperationScreenState();
}

class _BranchOperationScreenState extends ConsumerState<BranchOperationScreen> {
  final _cashController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _cashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(branchOperationControllerProvider);
    final user = ref.watch(authControllerProvider).value;
    final profilePhoto = ref.watch(profilePhotoControllerProvider).value;
    final isOpen = state.value?.isOpen ?? false;
    final activeOperation = state.value?.activeOperation;
    final openingUserPhoto = activeOperation == null
        ? null
        : ref
              .watch(
                profilePhotoForUserProvider(activeOperation.openingUserGuid),
              )
              .value;
    final inventoryValue = state.value?.currentInventoryValue ?? 0;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: isOpen ? 'Cierre de jornada' : 'Apertura de tienda',
            subtitle: isOpen
                ? 'Finaliza tu jornada de trabajo'
                : 'Inicia tu jornada de trabajo',
            height: 240 + MediaQuery.paddingOf(context).top,
            showBackButton: true,
            onBack: context.pop,
            content: isOpen
                ? _ClosingTimeHeader(
                    openingUserName:
                        activeOperation?.openingUserName ?? 'Usuario',
                    photoBytes: openingUserPhoto,
                  )
                : _InventoryValueHeader(
                    value: inventoryValue,
                    subtitle: 'Valor del inventario al momento',
                  ),
          ),
          Expanded(
            child: state.when(
              data: (value) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: value.isOpen
                        ? _closingContent(value)
                        : _openingContent(
                            value,
                            user?.name ?? 'Usuario',
                            user?.email ?? '',
                            user?.profile ?? '',
                            profilePhoto,
                          ),
                  ),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _OperationError(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(branchOperationControllerProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _openingContent(
    BranchOperationState state,
    String userName,
    String email,
    String profile,
    Uint8List? profilePhoto,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CashierCard(
          name: userName,
          email: email,
          profile: profile,
          photoBytes: profilePhoto,
        ),
        const SizedBox(height: 14),
        _SectionCard(
          icon: Icons.payments_outlined,
          title: 'Monto inicial de caja',
          subtitle: 'Efectivo con el que iniciarás la jornada',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Monto inicial',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _cashController,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  prefixText: '\$  ',
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      color: AppColors.primaryBlue,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este monto se registrará como saldo inicial de la caja.',
                        style: TextStyle(
                          color: AppColors.navySoft,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          icon: Icons.edit_note_rounded,
          title: 'Observaciones',
          subtitle: 'Información opcional de esta apertura',
          child: TextField(
            controller: _notesController,
            maxLength: 150,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Escribe tus observaciones aquí...',
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _OpeningRegistration(
          userName: userName,
          initialAmount: double.tryParse(_cashController.text.trim()) ?? 0,
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          text: 'Iniciar apertura de tienda',
          onPressed: _open,
          paddingVertical: 15,
          bg: AppColors.primaryBlue,
        ),
        const SizedBox(height: 10),
        const Text(
          'Sólo puede existir una jornada activa por sucursal.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGrey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _closingContent(BranchOperationState state) {
    final operation = state.activeOperation!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Jornada iniciada ${_dateTime(operation.startDate)} por ${operation.openingUserName}',
          style: const TextStyle(color: AppColors.textGrey, fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        _CloseInventoryCard(
          operation: operation,
          currentInventory: state.currentInventoryValue,
        ),
        const SizedBox(height: 14),
        _IncomeAndDocuments(operation: operation),
        const SizedBox(height: 14),
        _AdditionalMovements(operation: operation),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verifica la información antes de cerrar. Una vez finalizada, la jornada no podrá modificarse.',
                  style: TextStyle(color: AppColors.navySoft, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          text: 'Cerrar jornada',
          onPressed: _confirmClose,
          paddingVertical: 15,
          bg: AppColors.primaryBlue,
        ),
        const SizedBox(height: 10),
        const Text(
          'Al cerrar la jornada se bloquearán nuevas ventas hasta una nueva apertura.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGrey, fontSize: 11),
        ),
      ],
    );
  }

  Future<void> _open() async {
    final amount = double.tryParse(_cashController.text.trim()) ?? 0;
    final success = await ref
        .read(branchOperationControllerProvider.notifier)
        .open(
          initialCashAmount: amount,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text,
        );
    if (!mounted) return;
    _showMessage(
      success
          ? 'La jornada inició correctamente.'
          : ref.read(branchOperationControllerProvider).error.toString(),
      success: success,
    );
  }

  Future<void> _confirmClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar jornada'),
        content: const Text(
          '¿Deseas finalizar la operación activa? Esta acción habilitará una nueva apertura.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Cerrar jornada'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ref
        .read(branchOperationControllerProvider.notifier)
        .close();
    if (!mounted) return;
    _showMessage(
      success
          ? 'La jornada se cerró correctamente.'
          : ref.read(branchOperationControllerProvider).error.toString(),
      success: success,
    );
  }

  void _showMessage(String message, {required bool success}) {
    final color = success ? AppColors.success : AppColors.error;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: success
              ? AppColors.successSoft
              : AppColors.errorSoft,
          behavior: SnackBarBehavior.floating,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withValues(alpha: .2)),
          ),
          content: Row(
            children: [
              Icon(success ? Icons.check_circle : Icons.error, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.navy),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static String _dateTime(DateTime value) {
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _ClosingTimeHeader extends StatelessWidget {
  final String openingUserName;
  final Uint8List? photoBytes;

  const _ClosingTimeHeader({
    required this.openingUserName,
    required this.photoBytes,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const months = [
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
    String two(int value) => value.toString().padLeft(2, '0');
    final hour = now.hour == 0
        ? 12
        : (now.hour > 12 ? now.hour - 12 : now.hour);
    final period = now.hour >= 12 ? 'p. m.' : 'a. m.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Fecha y hora de cierre',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  '${now.day} ${months[now.month - 1]} ${now.year} · '
                  '$hour:${two(now.minute)} $period',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.white,
                      backgroundImage: photoBytes == null
                          ? null
                          : MemoryImage(photoBytes!),
                      child: photoBytes == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: AppColors.primaryBlue,
                              size: 13,
                            )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Apertura: $openingUserName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryValueHeader extends StatelessWidget {
  final double value;
  final String subtitle;
  const _InventoryValueHeader({required this.value, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now().format(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '\$${value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Calculado hoy $now',
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CashierCard extends StatelessWidget {
  final String name;
  final String email;
  final String profile;
  final Uint8List? photoBytes;
  const _CashierCard({
    required this.name,
    required this.email,
    required this.profile,
    required this.photoBytes,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.borderGrey),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primaryLight,
              child: Icon(
                Icons.person_outline_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Cajero que realiza la apertura',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: photoBytes == null
                  ? null
                  : MemoryImage(photoBytes!),
              child: photoBytes == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: AppColors.primaryBlue,
                      size: 40,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (profile.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        profile,
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11,
                      ),
                    ),
                  if (email.isNotEmpty)
                    Text(
                      'Usuario: ${email.split('@').first}',
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11,
                      ),
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

class _OpeningRegistration extends StatelessWidget {
  final String userName;
  final double initialAmount;
  const _OpeningRegistration({
    required this.userName,
    required this.initialAmount,
  });

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.now().format(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Al iniciar la apertura se registrarán:',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OpeningDatum(label: 'Hora de inicio', value: time),
              ),
              Expanded(
                child: _OpeningDatum(
                  label: 'Monto inicial',
                  value: '\$${initialAmount.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _OpeningDatum(label: 'Cajero', value: userName),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpeningDatum extends StatelessWidget {
  final String label;
  final String value;
  const _OpeningDatum({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 9.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.borderGrey),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _CloseInventoryCard extends StatelessWidget {
  final BranchOperation operation;
  final double currentInventory;
  const _CloseInventoryCard({
    required this.operation,
    required this.currentInventory,
  });

  @override
  Widget build(BuildContext context) => _SectionCard(
    icon: Icons.inventory_2_outlined,
    title: 'Inventario',
    child: Column(
      children: [
        _SummaryRow(
          label: 'Valor inicial del inventario',
          value: operation.initialInventoryValue,
        ),
        _SummaryRow(label: 'Valor compras', value: operation.purchasesValue),
        _SummaryRow(label: 'Valor ventas', value: operation.salesValue),
        _SummaryRow(
          label: 'Descuentos aplicados',
          value: operation.appliedDiscounts,
        ),
        _SummaryRow(
          label: 'Ajuste de inventario',
          value: operation.inventoryAdjustment,
        ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.primaryLight),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Valor final del inventario',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '\$${currentInventory.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _IncomeAndDocuments extends StatelessWidget {
  final BranchOperation operation;
  const _IncomeAndDocuments({required this.operation});

  @override
  Widget build(BuildContext context) {
    final totalIncome =
        operation.cashIncome +
        operation.cardIncome +
        operation.checkIncome +
        operation.transferIncome +
        operation.otherIncome;
    final totalCfdi =
        operation.cashCfdi +
        operation.cardCfdi +
        operation.checkCfdi +
        operation.transferCfdi +
        operation.otherCfdi;
    final income = _CompactSummaryCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Ingresos',
      accent: AppColors.success,
      rows: [
        _CompactRow('Efectivo', '\$${operation.cashIncome.toStringAsFixed(2)}'),
        _CompactRow('Tarjetas', '\$${operation.cardIncome.toStringAsFixed(2)}'),
        _CompactRow('Cheques', '\$${operation.checkIncome.toStringAsFixed(2)}'),
        _CompactRow(
          'Transferencia',
          '\$${operation.transferIncome.toStringAsFixed(2)}',
        ),
        _CompactRow('Otros', '\$${operation.otherIncome.toStringAsFixed(2)}'),
      ],
      totalLabel: 'Total ingresos',
      totalValue: '\$${totalIncome.toStringAsFixed(2)}',
    );
    final documents = _CompactSummaryCard(
      icon: Icons.description_outlined,
      title: 'Documentos (CFDI)',
      accent: const Color(0xFF7138C8),
      rows: [
        _CompactRow('Efectivo', '${operation.cashCfdi}'),
        _CompactRow('Tarjetas', '${operation.cardCfdi}'),
        _CompactRow('Cheques', '${operation.checkCfdi}'),
        _CompactRow('Transferencia', '${operation.transferCfdi}'),
        _CompactRow('Otros', '${operation.otherCfdi}'),
      ],
      totalLabel: 'Total CFDI',
      totalValue: '$totalCfdi',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 440) {
          return Column(
            children: [income, const SizedBox(height: 14), documents],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: income),
            const SizedBox(width: 14),
            Expanded(child: documents),
          ],
        );
      },
    );
  }
}

class _CompactRow {
  final String label;
  final String value;
  const _CompactRow(this.label, this.value);
}

class _CompactSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final List<_CompactRow> rows;
  final String totalLabel;
  final String totalValue;
  const _CompactSummaryCard({
    required this.icon,
    required this.title,
    required this.accent,
    required this.rows,
    required this.totalLabel,
    required this.totalValue,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.borderGrey),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  row.value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.only(top: 7),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  totalLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                totalValue,
                style: TextStyle(
                  color: accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AdditionalMovements extends StatelessWidget {
  final BranchOperation operation;
  const _AdditionalMovements({required this.operation});

  @override
  Widget build(BuildContext context) {
    final totalIncome =
        operation.cashIncome +
        operation.cardIncome +
        operation.checkIncome +
        operation.transferIncome +
        operation.otherIncome;
    final closingCash =
        operation.initialCashAmount +
        totalIncome +
        operation.incomingVouchers -
        operation.outgoingVouchers;
    return _SectionCard(
      icon: Icons.swap_vert_rounded,
      title: 'Movimientos adicionales',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              children: [
                _SummaryRow(label: 'Créditos', value: operation.credits),
                _SummaryRow(
                  label: 'Vales de salida',
                  value: operation.outgoingVouchers,
                ),
                _SummaryRow(
                  label: 'Vales entrantes',
                  value: operation.incomingVouchers,
                ),
                _SummaryRow(
                  label: 'Bajas de mercancía',
                  value: operation.merchandiseLosses,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 150,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE1A3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fondo de caja al cierre',
                  style: TextStyle(color: Color(0xFFAD6700), fontSize: 10.5),
                ),
                const SizedBox(height: 5),
                Text(
                  '\$${closingCash.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFB96A00),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  const _SummaryRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
        ),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _OperationError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _OperationError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
