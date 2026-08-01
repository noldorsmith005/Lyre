import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SafeStorage {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
      useDataProtectionKeyChain: false,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> write({required String key, required String value}) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> read({required String key}) async {
    return await _secureStorage.read(key: key);
  }

  Future<void> delete({required String key}) async {
    await _secureStorage.delete(key: key);
  }
}
