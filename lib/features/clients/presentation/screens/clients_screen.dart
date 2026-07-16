import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:kommerze_mobile/features/clients/presentation/controllers/clients_controller.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientsControllerProvider);
    final clients = state.value ?? const <Client>[];
    final visibleClients = _filter(clients);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Clientes',
            subtitle: 'Gestiona la información de tus clientes',
            height: 174 + MediaQuery.paddingOf(context).top,
            showBackButton: true,
            onBack: context.pop,
            content: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.navy, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, RFC o correo...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: state.when(
              skipLoadingOnRefresh: true,
              data: (_) => _content(clients, visibleClients),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openClientForm(),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 1,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
        label: const Text(
          'Nuevo cliente',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _content(List<Client> clients, List<Client> visibleClients) {
    final totalCredit = clients
        .where((client) => client.isActive)
        .fold<double>(0, (total, client) => total + client.creditAmount);
    final averageDays = clients.isEmpty
        ? 0
        : clients.fold<int>(0, (total, client) => total + client.creditDays) /
              clients.length;
    final currentMonth = DateTime.now();
    final newThisMonth = clients.where((client) {
      return client.createdAt.year == currentMonth.year &&
          client.createdAt.month == currentMonth.month;
    }).length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final columns = constraints.maxWidth >= 620 ? 4 : 2;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 10)) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatCard(
                      width: width,
                      icon: Icons.groups_outlined,
                      label: 'Total clientes',
                      value: '${clients.length}',
                      color: AppColors.primaryBlue,
                    ),
                    _StatCard(
                      width: width,
                      icon: Icons.person_add_alt_rounded,
                      label: 'Nuevos este mes',
                      value: '$newThisMonth',
                      color: AppColors.success,
                    ),
                    _StatCard(
                      width: width,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Crédito otorgado',
                      value: _money(totalCredit),
                      color: const Color(0xFF7138C8),
                    ),
                    _StatCard(
                      width: width,
                      icon: Icons.schedule_rounded,
                      label: 'Días promedio',
                      value: averageDays.toStringAsFixed(0),
                      color: const Color(0xFFE66A16),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (visibleClients.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyClients(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
            sliver: SliverList.separated(
              itemCount: visibleClients.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _ClientCard(
                client: visibleClients[index],
                onEdit: () => _openClientForm(visibleClients[index]),
                onToggle: () => _toggle(visibleClients[index]),
                onDelete: () => _delete(visibleClients[index]),
              ),
            ),
          ),
      ],
    );
  }

  List<Client> _filter(List<Client> clients) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return clients;
    return clients
        .where((client) {
          return client.name.toLowerCase().contains(query) ||
              client.rfc.toLowerCase().contains(query) ||
              client.email.toLowerCase().contains(query) ||
              client.phone.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _openClientForm([Client? client]) async {
    final saved = await context.push<bool>(
      AppConstants.clientFormScreenRoute,
      extra: client,
    );
    if (saved != true || !mounted) return;
    _message(
      client == null
          ? 'Cliente creado correctamente.'
          : 'Cliente actualizado correctamente.',
      success: true,
    );
  }

  Future<void> _toggle(Client client) async {
    final success = await ref
        .read(clientsControllerProvider.notifier)
        .toggle(client);
    if (!mounted) return;
    _message(
      success
          ? client.isActive
                ? 'Cliente inactivado.'
                : 'Cliente activado.'
          : 'No fue posible actualizar el cliente.',
      success: success,
    );
  }

  Future<void> _delete(Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Deseas eliminar a ${client.name}?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ref
        .read(clientsControllerProvider.notifier)
        .delete(client);
    if (!mounted) return;
    _message(
      success
          ? 'Cliente eliminado.'
          : ref.read(clientsControllerProvider.notifier).lastError ??
                'No fue posible eliminar el cliente.',
      success: success,
    );
  }

  void _message(String message, {required bool success}) {
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
          content: Text(message, style: const TextStyle(color: AppColors.navy)),
        ),
      );
  }

  static String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

class _StatCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 104,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.borderGrey),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 10.5),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _ClientCard({
    required this.client,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.borderGrey),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: AppColors.primaryLight,
          child: Text(
            _initials(client.name),
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      client.name,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Status(active: client.isActive),
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: PopupMenuButton<_ClientAction>(
                      padding: EdgeInsets.zero,
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: AppColors.borderGrey.withValues(alpha: .8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.navySoft,
                        size: 21,
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case _ClientAction.edit:
                            onEdit();
                          case _ClientAction.toggle:
                            onToggle();
                          case _ClientAction.delete:
                            onDelete();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: _ClientAction.edit,
                          child: _ClientMenuLabel(
                            icon: Icons.edit_outlined,
                            text: 'Editar',
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        PopupMenuItem(
                          value: _ClientAction.toggle,
                          child: _ClientMenuLabel(
                            icon: client.isActive
                                ? Icons.pause_circle_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            text: client.isActive ? 'Inactivar' : 'Activar',
                            color: client.isActive
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        const PopupMenuItem(
                          value: _ClientAction.delete,
                          child: _ClientMenuLabel(
                            icon: Icons.delete_outline_rounded,
                            text: 'Eliminar',
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                client.guid,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 9.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ClientDatum(label: 'RFC', value: client.rfc),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ClientDatum(label: 'Teléfono', value: client.phone),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ClientDatum(
                      label: 'Crédito',
                      value: '\$${client.creditAmount.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ClientDatum(
                label: 'Días crédito',
                value: '${client.creditDays} días',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

enum _ClientAction { edit, toggle, delete }

class _ClientMenuLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _ClientMenuLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Text(
        text,
        style: TextStyle(
          color: color == AppColors.error ? AppColors.error : AppColors.navy,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _Status extends StatelessWidget {
  final bool active;
  const _Status({required this.active});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: active ? AppColors.successSoft : AppColors.errorSoft,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      active ? 'Activo' : 'Inactivo',
      style: TextStyle(
        color: active ? AppColors.success : AppColors.error,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ClientDatum extends StatelessWidget {
  final String label;
  final String value;
  const _ClientDatum({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textGrey, fontSize: 9.5),
      ),
      Text(
        value.isEmpty ? '—' : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _EmptyClients extends StatelessWidget {
  const _EmptyClients();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.groups_outlined, color: AppColors.textGrey, size: 44),
        SizedBox(height: 10),
        Text(
          'Aún no hay clientes registrados.',
          style: TextStyle(color: AppColors.textGrey),
        ),
      ],
    ),
  );
}
