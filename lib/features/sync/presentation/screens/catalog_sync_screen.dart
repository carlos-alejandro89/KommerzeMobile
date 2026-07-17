import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/sync/domain/entities/catalog_sync_item.dart';
import 'package:kommerze_mobile/features/sync/presentation/controllers/catalog_sync_controller.dart';

class CatalogSyncScreen extends ConsumerStatefulWidget {
  const CatalogSyncScreen({super.key});

  @override
  ConsumerState<CatalogSyncScreen> createState() => _CatalogSyncScreenState();
}

class _CatalogSyncScreenState extends ConsumerState<CatalogSyncScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(catalogSyncControllerProvider.notifier)
          .restoreLocalStatus();
      if (!mounted) return;
      final error = ref.read(catalogSyncControllerProvider.notifier).lastError;
      if (error != null) {
        _message(context, error, success: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogSyncControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          const AppHeader(
            title: 'Sync',
            subtitle: 'Mantén la información local actualizada',
            height: 112,
            showBackButton: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _LastSyncCard(
                  state: state,
                  onSyncAll: () => _syncAll(context, ref),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Catálogos disponibles',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in state.catalogs) ...[
                  _CatalogCard(
                    item: item,
                    onTap: () => _sync(context, ref, item),
                  ),
                  const SizedBox(height: 9),
                ],
                const SizedBox(height: 10),
                _SummaryCard(state: state),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primaryBlue,
                        size: 22,
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Información importante',
                              style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'La sincronización descarga los catálogos más recientes desde Kommerze Cloud y los conserva localmente para trabajar con información actualizada.',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 11.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(
    BuildContext context,
    WidgetRef ref,
    CatalogSyncItem item,
  ) async {
    final success = await ref
        .read(catalogSyncControllerProvider.notifier)
        .synchronize(item.type);
    if (!context.mounted) return;
    final controller = ref.read(catalogSyncControllerProvider.notifier);
    _message(
      context,
      success
          ? '${item.title} se sincronizó correctamente.'
          : controller.lastError ?? 'No fue posible sincronizar ${item.title}.',
      success: success,
    );
  }

  Future<void> _syncAll(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(catalogSyncControllerProvider.notifier)
        .synchronizeAll();
    if (!context.mounted) return;
    final controller = ref.read(catalogSyncControllerProvider.notifier);
    _message(
      context,
      success
          ? 'Los catálogos configurados se sincronizaron correctamente.'
          : controller.lastError ??
                'No fue posible completar la sincronización.',
      success: success,
    );
  }

  void _message(BuildContext context, String text, {required bool success}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
}

class _LastSyncCard extends StatelessWidget {
  final CatalogSyncState state;
  final VoidCallback onSyncAll;
  const _LastSyncCard({required this.state, required this.onSyncAll});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sync_rounded,
                color: AppColors.primaryBlue,
                size: 26,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Última sincronización',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 11.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    state.lastSynchronization == null
                        ? 'Sin sincronizaciones'
                        : _date(state.lastSynchronization!),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Origen: Kommerze Cloud',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: state.synchronizingAll ? null : onSyncAll,
            icon: state.synchronizingAll
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, size: 19),
            label: Text(
              state.synchronizingAll ? 'Procesando' : 'Sincronizar todo',
              maxLines: 1,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CatalogCard extends StatelessWidget {
  final CatalogSyncItem item;
  final VoidCallback onTap;
  const _CatalogCard({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = _color(item.type);
    final status = _status(item.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: item.status == CatalogSyncStatus.syncing ? null : onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon(item.type), color: color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
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
                      item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 10.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${item.records} registros',
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status.color.withValues(alpha: .11),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.status == CatalogSyncStatus.syncing)
                                SizedBox(
                                  width: 11,
                                  height: 11,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: status.color,
                                  ),
                                )
                              else
                                Icon(
                                  status.icon,
                                  color: status.color,
                                  size: 12,
                                ),
                              const SizedBox(width: 4),
                              Text(
                                status.label,
                                style: TextStyle(
                                  color: status.color,
                                  fontSize: 10,
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
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textGrey,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CatalogSyncState state;
  const _SummaryCard({required this.state});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen de sincronización',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _SummaryValue(
                icon: Icons.storage_rounded,
                value: '${state.totalRecords}',
                label: 'Registros',
                color: AppColors.primaryBlue,
              ),
            ),
            Expanded(
              child: _SummaryValue(
                icon: Icons.check_circle_outline_rounded,
                value: '${state.synchronizedRecords}',
                label: 'Sincronizados',
                color: AppColors.success,
              ),
            ),
            Expanded(
              child: _SummaryValue(
                icon: Icons.schedule_rounded,
                value: '${state.pendingCatalogs}',
                label: 'Pendientes',
                color: AppColors.warning,
              ),
            ),
            Expanded(
              child: _SummaryValue(
                icon: Icons.error_outline_rounded,
                value: '${state.errors}',
                label: 'Errores',
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _SummaryValue({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textGrey, fontSize: 9.5),
      ),
    ],
  );
}

IconData _icon(CatalogType type) => switch (type) {
  CatalogType.paymentForms => Icons.credit_card_rounded,
  CatalogType.paymentMethods => Icons.view_agenda_outlined,
  CatalogType.profiles => Icons.manage_accounts_outlined,
  CatalogType.users => Icons.person_add_alt_1_rounded,
  CatalogType.clients => Icons.groups_2_outlined,
  CatalogType.orderTypes => Icons.assignment_outlined,
  CatalogType.statuses => Icons.bookmark_border_rounded,
};
Color _color(CatalogType type) => switch (type) {
  CatalogType.paymentForms => const Color(0xFF7138C8),
  CatalogType.paymentMethods => AppColors.primaryBlue,
  CatalogType.profiles => const Color(0xFFE66A16),
  CatalogType.users => AppColors.success,
  CatalogType.clients => const Color(0xFF008C95),
  CatalogType.orderTypes => const Color(0xFFE33B6A),
  CatalogType.statuses => AppColors.warning,
};

class _StatusData {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusData(this.label, this.color, this.icon);
}

_StatusData _status(CatalogSyncStatus status) => switch (status) {
  CatalogSyncStatus.pending => const _StatusData(
    'Pendiente',
    AppColors.warning,
    Icons.schedule_rounded,
  ),
  CatalogSyncStatus.syncing => const _StatusData(
    'Procesando',
    AppColors.primaryBlue,
    Icons.sync_rounded,
  ),
  CatalogSyncStatus.synchronized => const _StatusData(
    'Sincronizado',
    AppColors.success,
    Icons.check_circle_outline_rounded,
  ),
  CatalogSyncStatus.error => const _StatusData(
    'Error',
    AppColors.error,
    Icons.error_outline_rounded,
  ),
};

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
