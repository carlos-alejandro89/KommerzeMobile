import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const profilePhotoPreferenceKey = 'profile_photo_base64';

class ProfilePhotoController extends AsyncNotifier<Uint8List?> {
  @override
  Future<Uint8List?> build() async {
    final preferences = await SharedPreferences.getInstance();
    final encodedPhoto = preferences.getString(profilePhotoPreferenceKey);
    if (encodedPhoto == null) return null;

    try {
      return base64Decode(encodedPhoto);
    } on FormatException {
      await preferences.remove(profilePhotoPreferenceKey);
      return null;
    }
  }

  Future<void> save(Uint8List bytes) async {
    state = AsyncData(bytes);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(profilePhotoPreferenceKey, base64Encode(bytes));
  }

  Future<void> remove() async {
    state = const AsyncData(null);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(profilePhotoPreferenceKey);
  }
}

final profilePhotoControllerProvider =
    AsyncNotifierProvider<ProfilePhotoController, Uint8List?>(
      ProfilePhotoController.new,
    );
