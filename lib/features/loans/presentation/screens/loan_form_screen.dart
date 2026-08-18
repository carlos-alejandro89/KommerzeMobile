import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:kommerze_mobile/features/clients/presentation/widgets/selected_client_card.dart';
import 'package:kommerze_mobile/features/collections/presentation/controllers/collections_controller.dart';
import 'package:kommerze_mobile/features/loans/data/repositories/loans_repository.dart';
import 'package:kommerze_mobile/features/loans/domain/entities/customer_loan.dart';
import 'package:kommerze_mobile/features/loans/presentation/controllers/loans_controller.dart';

class LoanFormScreen extends ConsumerStatefulWidget {
  const LoanFormScreen({super.key});
  @override
  ConsumerState<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends ConsumerState<LoanFormScreen> {
  final _amount = TextEditingController();
  final _concept = TextEditingController();
  Client? _client;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  double get amount => double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    _concept.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.lightBackground,
    body: Column(
      children: [
        AppHeader(
          title: 'Nuevo préstamo',
          subtitle: 'Entrega efectivo a un cliente',
          height: 112 + MediaQuery.paddingOf(context).top,
          showBackButton: true,
          onBack: _saving ? null : context.pop,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section(
                title: 'Cliente',
                icon: Icons.person_outline_rounded,
                child: _client == null
                    ? InkWell(
                        onTap: _selectClient,
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
                                'Selecciona el cliente del préstamo',
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SelectedClientCard(
                        client: _client!,
                        onTap: _selectClient,
                      ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Datos del préstamo',
                icon: Icons.payments_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Monto en efectivo'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _amount,
                      autofocus: false,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration('0.00', prefix: '\$ '),
                    ),
                    const SizedBox(height: 15),
                    const _Label('Fecha de vencimiento'),
                    const SizedBox(height: 7),
                    InkWell(
                      onTap: _pickDueDate,
                      child: InputDecorator(
                        decoration: _inputDecoration(''),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: AppColors.primaryBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat(
                                'dd MMMM yyyy',
                                'es_MX',
                              ).format(_dueDate),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const _Label('Concepto o nota (opcional)'),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _concept,
                      maxLength: 150,
                      maxLines: 3,
                      decoration: _inputDecoration('Motivo del préstamo...'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
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
                        'El préstamo se agregará al estado de cuenta y los abonos se aplicarán automáticamente por antigüedad.',
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
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _client != null && amount > 0 && !_saving
                    ? _save
                    : null,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.payments_outlined),
                label: Text(_saving ? 'Registrando...' : 'Registrar préstamo'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _selectClient() async {
    final selected = await context.push<Client>(AppConstants.loanClientRoute);
    if (selected != null && mounted) setState(() => _client = selected);
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('es', 'MX'),
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) setState(() => _dueDate = selected);
  }

  Future<void> _save() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.payments_outlined,
          color: AppColors.primaryBlue,
          size: 34,
        ),
        title: const Text('Confirmar préstamo'),
        content: Text(
          'Se entregarán \$${amount.toStringAsFixed(2)} en efectivo a ${_client!.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(loansRepositoryProvider)
          .create(
            CustomerLoanDraft(
              clientGuid: _client!.guid,
              amount: amount,
              dueDate: _dueDate,
              concept: _concept.text,
            ),
          );
      ref.invalidate(loansProvider);
      ref.invalidate(collectionsDashboardProvider);
      ref.invalidate(collectionClientDetailProvider(_client!.guid));
      if (mounted) context.pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
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
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.navy,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}

InputDecoration _inputDecoration(String hint, {String? prefix}) =>
    InputDecoration(
      hintText: hint,
      prefixText: prefix,
      filled: true,
      fillColor: AppColors.primarySurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
    );
