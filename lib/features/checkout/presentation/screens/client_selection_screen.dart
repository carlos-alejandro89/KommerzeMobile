import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:kommerze_mobile/features/clients/presentation/controllers/clients_controller.dart';

class ClientSelectionScreen extends ConsumerStatefulWidget {
  const ClientSelectionScreen({super.key});

  @override
  ConsumerState<ClientSelectionScreen> createState() =>
      _ClientSelectionScreenState();
}

class _ClientSelectionScreenState extends ConsumerState<ClientSelectionScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsState = ref.watch(clientsControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Seleccionar cliente',
            subtitle: 'Asigna un cliente a la venta',
            height: 166,
            showBackButton: true,
            content: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Nombre, RFC, teléfono o correo',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: clientsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (clients) {
                final query = _search.text.trim().toLowerCase();
                final visible = clients
                    .where((client) {
                      if (!client.isActive) return false;
                      return query.isEmpty ||
                          client.name.toLowerCase().contains(query) ||
                          client.rfc.toLowerCase().contains(query) ||
                          client.email.toLowerCase().contains(query) ||
                          client.phone.contains(query);
                    })
                    .toList(growable: false);
                if (visible.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay clientes disponibles.',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, index) => _ClientOption(
                    client: visible[index],
                    onTap: () => context.pop(visible[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientOption extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;
  const _ClientOption({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                _initials(client.name),
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RFC ${client.rfc}${client.phone.isEmpty ? '' : '  •  ${client.phone}'}',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 11.5,
                    ),
                  ),
                  if (client.creditAmount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Crédito: ${_money(client.creditAmount)} · ${client.creditDays} días',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
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
      ),
    ),
  );
}

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
String _money(double value) => '\$${value.toStringAsFixed(2)}';
