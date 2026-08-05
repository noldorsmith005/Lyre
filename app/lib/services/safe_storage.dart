import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class SafeStorage {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
      useDataProtectionKeyChain: false,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static File? _file;
  static Map<String, String>? _cache;

  static Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/.safe_storage.json');
    return _file!;
  }

  static Future<Map<String, String>> _loadMap() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          _cache = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
          return _cache!;
        }
      }
    } catch (e) {
      debugPrint('Error reading local safe storage file: $e');
    }
    _cache = {};
    return _cache!;
  }

  static Future<void> _saveMap() async {
    try {
      final file = await _getFile();
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(_cache ?? {}));
    } catch (e) {
      debugPrint('Error writing local safe storage file: $e');
    }
  }

  Future<void> write({required String key, required String value}) async {
    final map = await _loadMap();
    map[key] = value;
    await _saveMap();
    if (!kIsWeb && Platform.isMacOS) {
      return;
    }
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<String?> read({required String key}) async {
    final map = await _loadMap();
    if (map.containsKey(key) && map[key] != null && map[key]!.isNotEmpty) {
      return map[key];
    }
    // Migration check from Keychain if not yet cached locally
    try {
      final val = await _secureStorage.read(key: key);
      if (val != null && val.isNotEmpty) {
        map[key] = val;
        await _saveMap();
        return val;
      }
    } catch (_) {}
    return null;
  }

  Future<void> delete({required String key}) async {
    final map = await _loadMap();
    map.remove(key);
    await _saveMap();
    if (!kIsWeb && Platform.isMacOS) {
      return;
    }
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
  }
}
