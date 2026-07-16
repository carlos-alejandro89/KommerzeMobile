import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/core/widgets/app_header.dart';
import 'package:kommerze_mobile/features/auth/domain/entities/usuario_entity.dart';
import 'package:kommerze_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kommerze_mobile/features/profile/presentation/controllers/profile_photo_controller.dart';
import 'package:kommerze_mobile/features/license/presentation/guards/license_guard.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();

  static String _displayName(UsuarioEntity? user) {
    final name = user?.name.trim() ?? '';
    return name.isEmpty ? 'Carlos Alejandro' : name;
  }

  static String _displayEmail(UsuarioEntity? user) {
    final email = user?.email.trim() ?? '';
    return email.contains('@') ? email : 'carlos@kommerze.com';
  }

  static String _displayUsername(UsuarioEntity? user) {
    final email = _displayEmail(user);
    return email.split('@').first;
  }

  static String _displayProfile(UsuarioEntity? user) {
    final profile = user?.profile.trim() ?? '';
    return profile.isEmpty ? 'Administrador' : profile;
  }
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _choosePhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    await ref.read(profilePhotoControllerProvider.notifier).save(bytes);
  }

  Future<void> _showPhotoOptions() async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PhotoOptionsSheet(
        hasPhoto: ref.read(profilePhotoControllerProvider).value != null,
      ),
    );
    if (action == _PhotoAction.choose) {
      await _choosePhoto();
    } else if (action == _PhotoAction.remove) {
      await ref.read(profilePhotoControllerProvider.notifier).remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authentication = ref.watch(authControllerProvider);
    final photoBytes = ref.watch(profilePhotoControllerProvider).value;
    final user = authentication.value;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          AppHeader(
            title: 'Mi perfil',
            height: 292,
            showBackButton: true,
            onBack: () => context.go(AppConstants.welcomeScreenRoute),
            actions: const [_NotificationAction(), SizedBox(width: 8)],
            content: _ProfileSummary(
              user: user,
              photoBytes: photoBytes,
              onChangePhoto: _showPhotoOptions,
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                  children: [
                    _ProfileSection(
                      title: 'Información personal',
                      items: [
                        _ProfileItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Nombre completo',
                          value: ProfileScreen._displayName(user),
                        ),
                        _ProfileItem(
                          icon: Icons.mail_outline_rounded,
                          label: 'Correo electrónico',
                          value: ProfileScreen._displayEmail(user),
                        ),
                        const _ProfileItem(
                          icon: Icons.phone_outlined,
                          label: 'Teléfono',
                          value: '+52 993 123 4567',
                        ),
                        _ProfileItem(
                          icon: Icons.badge_outlined,
                          label: 'Usuario',
                          value: ProfileScreen._displayUsername(user),
                        ),
                        _ProfileItem(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Rol',
                          value: ProfileScreen._displayProfile(user),
                        ),
                        const _ProfileItem(
                          icon: Icons.event_available_outlined,
                          label: 'Último inicio de sesión',
                          value: '07/05/2025 08:45 a. m.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _ProfileSection(
                      title: 'Seguridad',
                      items: [
                        _ProfileItem(
                          icon: Icons.lock_outline_rounded,
                          label: 'Cambiar contraseña',
                        ),
                        _ProfileItem(
                          icon: Icons.key_outlined,
                          label: 'Autenticación de dos factores',
                          value: 'Activo',
                          valueColor: Color(0xFF08A957),
                        ),
                        _ProfileItem(
                          icon: Icons.devices_outlined,
                          label: 'Dispositivos vinculados',
                          value: '2 dispositivos',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _ProfileSection(
                      title: 'Preferencias',
                      items: [
                        _ProfileItem(
                          icon: Icons.palette_outlined,
                          label: 'Tema de la aplicación',
                          value: 'Sistema',
                        ),
                        _ProfileItem(
                          icon: Icons.language_rounded,
                          label: 'Idioma',
                          value: 'Español',
                        ),
                        _ProfileItem(
                          icon: Icons.notifications_none_rounded,
                          label: 'Notificaciones',
                          value: 'Activadas',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _LogoutCard(
                      isLoading: authentication.isLoading,
                      onTap: () =>
                          ref.read(authControllerProvider.notifier).logout(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ProfileBottomNavigation(
        onProtectedTap: () => LicenseGuard.ensureActive(context, ref),
      ),
    );
  }
}

class _NotificationAction extends StatelessWidget {
  const _NotificationAction();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        Positioned(
          right: 1,
          top: 0,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
            child: const Text(
              '3',
              style: TextStyle(
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

enum _PhotoAction { choose, remove }

class _PhotoOptionsSheet extends StatelessWidget {
  final bool hasPhoto;

  const _PhotoOptionsSheet({required this.hasPhoto});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderGrey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              'Fotografía de perfil',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primaryBlue,
                ),
              ),
              title: const Text(
                'Elegir fotografía',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Seleccionar una imagen del dispositivo',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () => Navigator.pop(context, _PhotoAction.choose),
            ),
            if (hasPhoto)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFE9E7),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                ),
                title: const Text(
                  'Eliminar fotografía',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(context, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final UsuarioEntity? user;
  final Uint8List? photoBytes;
  final VoidCallback onChangePhoto;

  const _ProfileSummary({
    required this.user,
    required this.photoBytes,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onChangePhoto,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
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
                        size: 52,
                      )
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryLight),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primaryBlue,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ProfileScreen._displayName(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                ProfileScreen._displayProfile(user),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 14),
              _SummaryLine(
                icon: Icons.mail_outline_rounded,
                value: ProfileScreen._displayEmail(user),
              ),
              const SizedBox(height: 8),
              const _SummaryLine(
                icon: Icons.phone_outlined,
                value: '+52 993 123 4567',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final IconData icon;
  final String value;

  const _SummaryLine({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<_ProfileItem> items;

  const _ProfileSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.borderGrey.withValues(alpha: .7),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: .05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                items[index],
                if (index < items.length - 1)
                  const Divider(height: 1, indent: 68, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;

  const _ProfileItem({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.navySoft, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: valueColor ?? AppColors.textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.navySoft,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _LogoutCard({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFAFA),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD7D4)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE5E3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: AppColors.error),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Salir de tu cuenta en este dispositivo',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBottomNavigation extends StatelessWidget {
  final VoidCallback onProtectedTap;

  const _ProfileBottomNavigation({required this.onProtectedTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 82,
      padding: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ProfileNavItem(
            label: 'Inicio',
            icon: Icons.home_rounded,
            onTap: () => context.go(AppConstants.welcomeScreenRoute),
          ),
          _ProfileNavItem(
            label: 'Ventas',
            icon: Icons.shopping_cart_rounded,
            onTap: onProtectedTap,
          ),
          _ProfileNavItem(
            label: 'Reportes',
            icon: Icons.bar_chart_rounded,
            onTap: onProtectedTap,
          ),
          _ProfileNavItem(
            label: 'Más',
            icon: Icons.grid_view_rounded,
            selected: true,
            onTap: () => context.push(AppConstants.licenseScreenRoute),
          ),
        ],
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _ProfileNavItem({
    required this.label,
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.textGrey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
