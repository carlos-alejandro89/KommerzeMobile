import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/features/profile/presentation/controllers/profile_photo_controller.dart';
import 'package:kommerze_mobile/features/license/presentation/guards/license_guard.dart';
import 'package:kommerze_mobile/features/branch_operation/presentation/guards/branch_operation_guard.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_history_item.dart';
import 'package:kommerze_mobile/features/sales_history/presentation/controllers/sales_history_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _MenuLayout { list, grid }

const _menuLayoutPreferenceKey = 'welcome_menu_layout';

class WelcomeScreen extends ConsumerStatefulWidget {
  final String userName;

  const WelcomeScreen({super.key, this.userName = 'Carlos'});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  int _selectedIndex = 0;
  _MenuLayout _menuLayout = _MenuLayout.list;

  @override
  void initState() {
    super.initState();
    _loadMenuLayout();
  }

  Future<void> _loadMenuLayout() async {
    final preferences = await SharedPreferences.getInstance();
    final savedValue = preferences.getString(_menuLayoutPreferenceKey);
    if (!mounted || savedValue == null) return;

    setState(() {
      _menuLayout = savedValue == _MenuLayout.grid.name
          ? _MenuLayout.grid
          : _MenuLayout.list;
    });
  }

  Future<void> _chooseMenuLayout() async {
    final selected = await showModalBottomSheet<_MenuLayout>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MenuLayoutSheet(selected: _menuLayout),
    );
    if (selected == null || selected == _menuLayout) return;

    setState(() => _menuLayout = selected);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_menuLayoutPreferenceKey, selected.name);
  }

  @override
  Widget build(BuildContext context) {
    final profilePhoto = ref.watch(profilePhotoControllerProvider).value;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 116),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(photoBytes: profilePhoto),
                  const SizedBox(height: 28),
                  Text(
                    '¡Hola, ${_firstName(widget.userName)}! 👋',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Bienvenido a Kommerze',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SearchBar(onMenuLayoutPressed: _chooseMenuLayout),
                  const SizedBox(height: 18),
                  const _SalesCard(),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Módulos principales',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        _menuLayout == _MenuLayout.list
                            ? Icons.view_agenda_outlined
                            : Icons.grid_view_rounded,
                        color: AppColors.navy,
                        size: 19,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _menuLayout == _MenuLayout.list
                        ? _ModuleList(
                            key: const ValueKey('list'),
                            onModuleTap: _openModule,
                          )
                        : _QuickAccessGrid(
                            key: const ValueKey('grid'),
                            onModuleTap: _openModule,
                          ),
                  ),
                  const SizedBox(height: 22),
                  const _RecentActivity(),
                  const SizedBox(height: 18),
                  const _PromoBanner(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        selectedIndex: _selectedIndex,
        onSelected: _onNavigationSelected,
        onAdd: _openSales,
      ),
    );
  }

  String _firstName(String name) {
    final normalized = name.trim();
    return normalized.isEmpty ? 'Carlos' : normalized.split(' ').first;
  }

  Future<void> _onNavigationSelected(int index) async {
    if (index == 3) {
      context.push(AppConstants.licenseScreenRoute);
      return;
    }
    if (index == 1) {
      await _openSales();
      return;
    }
    if (index != 0) {
      await _openProtectedOption();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _openProtectedOption() async {
    final allowed = await LicenseGuard.ensureActive(context, ref);
    if (!allowed || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Este módulo estará disponible próximamente.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openModule(_QuickData module) async {
    final allowed = await LicenseGuard.ensureActive(context, ref);
    if (!allowed || !mounted) return;
    if (module.title == 'Inventario') {
      context.push(AppConstants.inventoryScreenRoute);
      return;
    }
    if (module.title == 'Caja') {
      context.push(AppConstants.branchOperationScreenRoute);
      return;
    }
    if (module.title == 'Clientes') {
      context.push(AppConstants.clientsScreenRoute);
      return;
    }
    if (module.title == 'Ventas') {
      await _openSales(licenseAlreadyValidated: true);
      return;
    }
    if (module.title == 'Compras') {
      final operationOpen = await BranchOperationGuard.ensureOpen(context, ref);
      if (!operationOpen || !mounted) return;
      context.push(AppConstants.purchasesScreenRoute);
      return;
    }
    if (module.title == 'Cobranza') {
      final operationOpen = await BranchOperationGuard.ensureOpen(context, ref);
      if (!operationOpen || !mounted) return;
      context.push(AppConstants.collectionsScreenRoute);
      return;
    }
    if (module.title == 'Sync') {
      context.push(AppConstants.catalogSyncScreenRoute);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Este módulo estará disponible próximamente.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openSales({bool licenseAlreadyValidated = false}) async {
    if (!licenseAlreadyValidated) {
      final licensed = await LicenseGuard.ensureActive(context, ref);
      if (!licensed || !mounted) return;
    }
    final operationOpen = await BranchOperationGuard.ensureOpen(context, ref);
    if (!operationOpen || !mounted) return;
    context.push(AppConstants.salesScreenRoute);
  }
}

class _Header extends StatelessWidget {
  final Uint8List? photoBytes;

  const _Header({required this.photoBytes});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: 54,
            height: 54,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Kommerze',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.25,
            ),
          ),
        ),
        _CircleAction(
          icon: Icons.notifications_none_rounded,
          onTap: () {},
          badge: '3',
        ),
        const SizedBox(width: 10),
        _ProfileAvatar(
          photoBytes: photoBytes,
          onTap: () => context.push(AppConstants.profileScreenRoute),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  const _CircleAction({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.primarySurface,
          elevation: 0,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: AppColors.primaryBlue, size: 24),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final VoidCallback onTap;
  final Uint8List? photoBytes;

  const _ProfileAvatar({required this.onTap, required this.photoBytes});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderGrey, width: 1.2),
              image: photoBytes == null
                  ? null
                  : DecorationImage(
                      image: MemoryImage(photoBytes!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: photoBytes == null
                ? const Icon(
                    Icons.person_rounded,
                    color: AppColors.navy,
                    size: 27,
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF0CCB71),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onMenuLayoutPressed;

  const _SearchBar({required this.onMenuLayoutPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: _whiteCard(radius: 14),
            child: const TextField(
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar en Kommerze...',
                hintStyle: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(Icons.search_rounded, size: 22),
                prefixIconConstraints: BoxConstraints(minWidth: 44),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 48,
          height: 48,
          decoration: _whiteCard(radius: 14),
          child: IconButton(
            onPressed: onMenuLayoutPressed,
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.view_quilt_outlined,
              color: AppColors.navySoft,
              size: 21,
            ),
          ),
        ),
      ],
    );
  }
}

class _SalesCard extends ConsumerWidget {
  const _SalesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(dailySalesAnalyticsProvider);
    final data = analytics.value ?? const DailySalesAnalytics.empty();
    final variation = data.variationPercentage;
    final positive = variation >= 0;
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF001E58), Color(0xFF003B98)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ventas del día', style: _whiteLabel),
                    const SizedBox(height: 3),
                    Text(
                      _homeMoney(data.todayTotal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.white,
                      size: 15,
                    ),
                    SizedBox(width: 5),
                    Text('Hoy', style: _whiteLabel),
                    SizedBox(width: 5),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Text('vs. ayer', style: _whiteLabel),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D58A).withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${positive ? '↗' : '↘'} ${variation.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: positive
                        ? const Color(0xFF00E59A)
                        : const Color(0xFFFFA38F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: analytics.isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white70,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: _SalesChartPainter(data.hourlyTotals),
                    child: data.todayTotal == 0
                        ? const Center(
                            child: Text(
                              'Sin ventas registradas hoy',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 10.5,
                              ),
                            ),
                          )
                        : null,
                  ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00:00', style: _chartLabel),
              Text('06:00', style: _chartLabel),
              Text('12:00', style: _chartLabel),
              Text('18:00', style: _chartLabel),
              Text('23:59', style: _chartLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuLayoutSheet extends StatelessWidget {
  final _MenuLayout selected;

  const _MenuLayoutSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderGrey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tipo de menú',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Elige cómo deseas visualizar los módulos.',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _LayoutOption(
              title: 'Lista compacta',
              subtitle: 'Más módulos visibles y navegación rápida',
              icon: Icons.view_agenda_outlined,
              selected: selected == _MenuLayout.list,
              onTap: () => Navigator.pop(context, _MenuLayout.list),
            ),
            const SizedBox(height: 10),
            _LayoutOption(
              title: 'Tarjetas',
              subtitle: 'Diseño visual con accesos destacados',
              icon: Icons.grid_view_rounded,
              selected: selected == _MenuLayout.grid,
              onTap: () => Navigator.pop(context, _MenuLayout.grid),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LayoutOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySurface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : AppColors.borderGrey,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryLight
                      : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primaryBlue : AppColors.borderGrey,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleList extends StatelessWidget {
  final ValueChanged<_QuickData> onModuleTap;

  const _ModuleList({super.key, required this.onModuleTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < _moduleItems.length; index++) ...[
          _ModuleListItem(
            data: _moduleItems[index],
            onTap: () => onModuleTap(_moduleItems[index]),
          ),
          if (index < _moduleItems.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ModuleListItem extends StatelessWidget {
  final _QuickData data;
  final VoidCallback onTap;

  const _ModuleListItem({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: _whiteCard(radius: 17),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: data.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: data.colors.last.withValues(alpha: .18),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(data.icon, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.subtitle.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryBlue,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  final ValueChanged<_QuickData> onModuleTap;

  const _QuickAccessGrid({super.key, required this.onModuleTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final item in _moduleItems)
              _QuickCard(
                data: item,
                width: width,
                onTap: () => onModuleTap(item),
              ),
          ],
        );
      },
    );
  }
}

class _QuickCard extends StatelessWidget {
  final _QuickData data;
  final double width;
  final VoidCallback onTap;

  const _QuickCard({
    required this.data,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 190,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: data.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: data.colors.last.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              bottom: -20,
              child: Icon(
                data.icon,
                size: 105,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, color: Colors.white, size: 29),
                ),
                const Spacer(),
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSalesProvider);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _whiteCard(radius: 20),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Actividad reciente',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    context.push(AppConstants.salesHistoryScreenRoute),
                label: const Text(
                  'Ver todas',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
          const Divider(height: 24),
          recent.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No fue posible consultar la actividad reciente.',
                style: TextStyle(color: AppColors.textGrey, fontSize: 11.5),
              ),
            ),
            data: (items) => items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Aún no hay ventas registradas.',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11.5,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        _RecentSaleTile(item: items[index]),
                        if (index < items.length - 1) const Divider(height: 18),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecentSaleTile extends StatelessWidget {
  final SaleHistoryItem item;
  const _RecentSaleTile({required this.item});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: item.isCredit
              ? const Color(0xFFFFF1E4)
              : AppColors.successSoft,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          Icons.shopping_cart_outlined,
          color: item.isCredit ? const Color(0xFFE66A16) : AppColors.success,
          size: 22,
        ),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Venta ${item.formattedFolio}',
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.clientName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 10.5),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _recentTime(item.date),
            style: const TextStyle(color: AppColors.textGrey, fontSize: 9.5),
          ),
          const SizedBox(height: 4),
          Text(
            _recentMoney(item.total),
            style: TextStyle(
              color: item.isCredit
                  ? const Color(0xFFE66A16)
                  : AppColors.success,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ],
  );
}

String _recentTime(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return 'Ahora';
  if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
  if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

String _recentMoney(double value) => '\$${value.toStringAsFixed(2)}';

String _homeMoney(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '\$${buffer.toString()}.${parts.last}';
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00256E), Color(0xFF0865DD)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kommerze siempre contigo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Gestiona tu negocio desde cualquier lugar y en cualquier dispositivo.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Icon(Icons.phone_android_rounded, color: Colors.white, size: 42),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 64,
      padding: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            index: 0,
            label: 'Inicio',
            icon: Icons.home_rounded,
            selectedIndex: selectedIndex,
            onTap: onSelected,
          ),
          _NavItem(
            index: 1,
            label: 'Ventas',
            icon: Icons.shopping_cart_rounded,
            selectedIndex: selectedIndex,
            onTap: onSelected,
          ),
          _AddMenuButton(onTap: onAdd),
          _NavItem(
            index: 2,
            label: 'Reportes',
            icon: Icons.bar_chart_rounded,
            selectedIndex: selectedIndex,
            onTap: onSelected,
          ),
          _NavItem(
            index: 3,
            label: 'Más',
            icon: Icons.grid_view_rounded,
            selectedIndex: selectedIndex,
            onTap: onSelected,
          ),
        ],
      ),
    );
  }
}

class _AddMenuButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: AppColors.primaryBlue,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final String label;
  final IconData icon;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.selectedIndex,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final color = selected ? AppColors.primaryBlue : AppColors.textGrey;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  final List<double> values;
  const _SalesChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height * .86;
    final grid = Paint()
      ..color = const Color(0xFF28A7FF).withValues(alpha: .25)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline), grid);

    if (values.isEmpty) return;
    final maximum = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final top = size.height * .08;
    final chartHeight = baseline - top;
    final points = <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
          values.length == 1 ? 0 : size.width * index / (values.length - 1),
          maximum <= 0
              ? baseline
              : baseline - (values[index] / maximum) * chartHeight,
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midX = (previous.dx + current.dx) / 2;
      path.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, baseline)
      ..lineTo(points.first.dx, baseline)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF28B8FF).withValues(alpha: .3),
            const Color(0xFF28B8FF).withValues(alpha: .02),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF37B8FF).withValues(alpha: .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF10A7FF), Color(0xFF75D6FF)],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final activePoints = <Offset>[
      for (var index = 0; index < points.length; index++)
        if (values[index] > 0) points[index],
    ];
    for (final point in activePoints) {
      canvas.drawCircle(point, 5, Paint()..color = const Color(0xFF6EDCFF));
      canvas.drawCircle(
        point,
        9,
        Paint()..color = const Color(0xFF25B7FF).withValues(alpha: .22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var index = 0; index < values.length; index++) {
      if (oldDelegate.values[index] != values[index]) return true;
    }
    return false;
  }
}

class _QuickData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;

  const _QuickData(this.title, this.subtitle, this.icon, this.colors);
}

const _moduleItems = [
  _QuickData(
    'Ventas',
    'Captura y consulta de ventas',
    Icons.shopping_cart_rounded,
    [Color(0xFF087CF4), Color(0xFF0647CF)],
  ),
  _QuickData(
    'Clientes',
    'Catálogo y gestión de clientes',
    Icons.people_alt_rounded,
    [Color(0xFF9746E8), Color(0xFF6F25C9)],
  ),
  _QuickData(
    'Compras',
    'Órdenes y control de compras',
    Icons.shopping_bag_rounded,
    [Color(0xFF20C8C2), Color(0xFF079B98)],
  ),
  _QuickData(
    'Caja',
    'Apertura, cierres y movimientos de caja',
    Icons.point_of_sale_rounded,
    [Color(0xFFFFBF22), Color(0xFFFF7A0A)],
  ),
  _QuickData(
    'Inventario',
    'Existencias, precios y sincronización',
    Icons.inventory_2_rounded,
    [Color(0xFF1678D3), Color(0xFF0647A8)],
  ),
  _QuickData(
    'Cobranza',
    'Cuentas por cobrar y abonos',
    Icons.request_quote_rounded,
    [Color(0xFF23A66F), Color(0xFF087A45)],
  ),
  _QuickData('Sync', 'Descarga y actualiza catálogos', Icons.sync_rounded, [
    Color(0xFF3D67D8),
    Color(0xFF173B9E),
  ]),
];

BoxDecoration _whiteCard({required double radius}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.borderGrey.withValues(alpha: .8)),
  boxShadow: [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: .06),
      blurRadius: 18,
      offset: const Offset(0, 7),
    ),
  ],
);

const _whiteLabel = TextStyle(
  color: Colors.white,
  fontSize: 13,
  fontWeight: FontWeight.w500,
);
const _chartLabel = TextStyle(
  color: Colors.white70,
  fontSize: 9,
  fontWeight: FontWeight.w400,
);
