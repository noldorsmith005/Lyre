import 'dart:io' show Platform;

/// Returns true on macOS or Windows (desktop targets)
bool get isDesktop => Platform.isMacOS || Platform.isWindows;

/// Returns true on Android or iOS (mobile targets)
bool get isMobile => Platform.isAndroid || Platform.isIOS;

/// Returns true if server management UI should be shown.
/// Mobile = local-only playback (no upload, download, register, etc.)
/// ServerClient is still available in the build for future sync.
bool get showServerFeatures => isDesktop;
