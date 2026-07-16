import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kommerze_mobile/app.dart';
import 'package:kommerze_mobile/core/storage/secure_storage_provider.dart';
import 'package:kommerze_mobile/core/storage/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPrefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage(aOptions: AndroidOptions());
  final isFirstTime = sharedPrefs.getBool('is_first_time') ?? true;

  if (isFirstTime) {
    await secureStorage.deleteAll();
    await sharedPrefs.setBool('is_first_time', false);
  }
  if (kReleaseMode) {
    await limpiarSecureStorageCorrupto(secureStorage);
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(sharedPrefs),
        secureStorageProvider.overrideWithValue(secureStorage),
      ],
      child: const App(),
    ),
  );
}
