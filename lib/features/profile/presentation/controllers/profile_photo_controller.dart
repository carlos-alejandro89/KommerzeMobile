import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kommerze_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyProfilePhotoPreferenceKey = 'profile_photo_base64';

String profilePhotoPreferenceKeyFor(String userGuid) =>
    'profile_photo_base64_${userGuid.trim().toLowerCase()}';

Future<Uint8List?> _readPhoto(String userGuid) async {
  if (userGuid.trim().isEmpty) return null;
  final preferences = await SharedPreferences.getInstance();
  final key = profilePhotoPreferenceKeyFor(userGuid);
  final encodedPhoto = preferences.getString(key);
  if (encodedPhoto == null) return null;
  try {
    return base64Decode(encodedPhoto);
  } on FormatException {
    await preferences.remove(key);
    return null;
  }
}

class ProfilePhotoController extends AsyncNotifier<Uint8List?> {
  String? _userGuid;

  @override
  Future<Uint8List?> build() async {
    final user = ref.watch(authControllerProvider).value;
    _userGuid = user?.userGuid.trim().isNotEmpty == true
        ? user!.userGuid
        : user?.id;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyProfilePhotoPreferenceKey);
    try {
      final remote = await ref.read(authRepoProvider).getProfilePicture();
      if (remote != null) {
        await _cache(remote);
        return remote;
      }
    } catch (_) {
      // Si no hay conexión se conserva la última imagen disponible localmente.
    }
    return _readPhoto(_userGuid ?? '');
  }

  Future<void> save(Uint8List bytes, {required String filename}) async {
    final userGuid = _userGuid;
    if (userGuid == null || userGuid.isEmpty) return;
    final previous = state.value;
    state = const AsyncLoading();
    try {
      final uploaded = await ref
          .read(authRepoProvider)
          .updateProfilePicture(bytes, filename: filename);
      state = AsyncData(uploaded);
      await _cache(uploaded);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> _cache(Uint8List bytes) async {
    final userGuid = _userGuid;
    if (userGuid == null || userGuid.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      profilePhotoPreferenceKeyFor(userGuid),
      base64Encode(bytes),
    );
  }

  Future<void> remove() async {
    final userGuid = _userGuid;
    state = const AsyncData(null);
    if (userGuid == null || userGuid.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(profilePhotoPreferenceKeyFor(userGuid));
  }
}

final profilePhotoControllerProvider =
    AsyncNotifierProvider<ProfilePhotoController, Uint8List?>(
      ProfilePhotoController.new,
    );

final profilePhotoForUserProvider = FutureProvider.family<Uint8List?, String>(
  (ref, userGuid) => _readPhoto(userGuid),
);
