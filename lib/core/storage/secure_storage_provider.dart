import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(aOptions: AndroidOptions());
});

Future<void> limpiarSecureStorageCorrupto(FlutterSecureStorage storage) async {
  try {
    await storage.read(key: 'token');
  } catch (e) {
    debugPrint("Llave criptografica perdida. Reseteando SecureStorage...");
    await storage.deleteAll();
  }
}
