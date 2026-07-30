import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class SafeStorage {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static File? _fallbackFile;
  static Map<String, String>? _fallbackData;

  static Future<File> _getFallbackFile() async {
    if (_fallbackFile != null) return _fallbackFile!;
    final dir = await getApplicationSupportDirectory();
    _fallbackFile = File('${dir.path}/.safe_storage_fallback.json');
    return _fallbackFile!;
  }

  static Future<Map<String, String>> _loadFallback() async {
    if (_fallbackData != null) return _fallbackData!;
    try {
      final file = await _getFallbackFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          _fallbackData = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
          return _fallbackData!;
        }
      }
    } catch (_) {}
    _fallbackData = {};
    return _fallbackData!;
  }

  static Future<void> _saveFallback() async {
    try {
      final file = await _getFallbackFile();
      await file.writeAsString(jsonEncode(_fallbackData ?? {}));
    } catch (_) {}
  }

  Future<void> write({required String key, required String value}) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      final data = await _loadFallback();
      data[key] = value;
      await _saveFallback();
    }
  }

  Future<String?> read({required String key}) async {
    try {
      final val = await _secureStorage.read(key: key);
      if (val != null) return val;
    } catch (e) {
      // Fallback
    }
    final data = await _loadFallback();
    return data[key];
  }

  Future<void> delete({required String key}) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      // Fallback
    }
    final data = await _loadFallback();
    if (data.containsKey(key)) {
      data.remove(key);
      await _saveFallback();
    }
  }
}
