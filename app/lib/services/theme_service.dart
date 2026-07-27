import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const String _storageKey = 'napster_theme_color_key';

  String _themeColorKey = 'red';

  ThemeService() {
    _loadThemeColor();
  }

  String get themeColorKey => _themeColorKey;

  Color get themeColor {
    switch (_themeColorKey) {
      case 'green':
        return const Color(0xFF0F5A2B);
      case 'blue':
        return const Color(0xFF0F3178);
      case 'purple':
        return const Color(0xFF4A148C);
      case 'red':
      default:
        return const Color.fromARGB(255, 200, 30, 30); // 0xFFC81E1E
    }
  }

  Color get themeColorAccent {
    switch (_themeColorKey) {
      case 'green':
        return const Color(0xFF25D366);
      case 'blue':
        return const Color(0xFF1A56DB);
      case 'purple':
        return const Color(0xFF9C27B0);
      case 'red':
      default:
        return const Color(0xFFE53935);
    }
  }

  Color get themeColorDark {
    switch (_themeColorKey) {
      case 'green':
        return const Color(0xFF0B4627);
      case 'blue':
        return const Color(0xFF0A2255);
      case 'purple':
        return const Color(0xFF310B5E);
      case 'red':
      default:
        return const Color(0xFF8C1D1D);
    }
  }

  Future<void> _loadThemeColor() async {
    try {
      final savedKey = await _storage.read(key: _storageKey);
      if (savedKey != null && ['red', 'green', 'blue', 'purple'].contains(savedKey)) {
        _themeColorKey = savedKey;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved theme color: $e');
    }
  }

  Future<void> setThemeColor(String key) async {
    if (!['red', 'green', 'blue', 'purple'].contains(key)) return;
    _themeColorKey = key;
    notifyListeners();
    try {
      await _storage.write(key: _storageKey, value: key);
    } catch (e) {
      debugPrint('Error saving theme color: $e');
    }
  }
}
