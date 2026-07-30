import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'safe_storage.dart';
import 'package:path_provider/path_provider.dart';

class ThemeService extends ChangeNotifier {
  static final _storage = SafeStorage();
  static const String _storageKey = 'lyre_theme_color_key';
  static const MethodChannel _platformChannel = MethodChannel('com.lyre.app/icon');

  String _themeColorKey = 'red';

  ThemeService() {
    _loadThemeColor();
  }

  String get themeColorKey => _themeColorKey;

  String get appIconAsset => 'assets/icons/app_icon_$_themeColorKey.png';
  String get appIconTransparentAsset => 'assets/icons/app_icon_${_themeColorKey}_transparent.png';

  static String getAppIconForTheme(String key, {bool transparent = true}) {
    final theme = ['red', 'green', 'blue', 'purple'].contains(key) ? key : 'red';
    return transparent
        ? 'assets/icons/app_icon_${theme}_transparent.png'
        : 'assets/icons/app_icon_$theme.png';
  }

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
        return const Color.fromARGB(255, 200, 30, 30);
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
        _updateNativeIcon(savedKey);
      }
    } catch (e) {
      debugPrint('Error loading saved theme color: $e');
    }
  }

  Future<void> setThemeColor(String key) async {
    if (!['red', 'green', 'blue', 'purple'].contains(key)) return;
    _themeColorKey = key;
    notifyListeners();
    _updateNativeIcon(key);
    try {
      await _storage.write(key: _storageKey, value: key);
    } catch (e) {
      debugPrint('Error saving theme color: $e');
    }
  }

  Future<void> _updateNativeIcon(String key) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _platformChannel.invokeMethod('setAppIcon', {'icon': key});
      } else if (Platform.isMacOS || Platform.isWindows) {
        final iconPath = await _getTempAssetFilePath(key);
        await _platformChannel.invokeMethod('setAppIcon', {'path': iconPath, 'icon': key});
      }
    } catch (e) {
      debugPrint('Native icon change notice: $e');
    }
  }

  Future<String> _getTempAssetFilePath(String key) async {
    final assetPath = 'assets/icons/app_icon_$key.png';
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/app_icon_$key.png');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return tempFile.path;
  }
}
