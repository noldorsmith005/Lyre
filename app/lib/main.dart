import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'services/media_handler.dart';
import 'services/server_client.dart';
import 'services/audio_player_service.dart';
import 'services/theme_service.dart';
import 'screens/home_screen.dart';
import 'screens/mobile/mobile_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/platform_utils.dart';

class PinnedCertificateHttpOverrides extends HttpOverrides {
  final List<int> trustedCertificateBytes;

  PinnedCertificateHttpOverrides(this.trustedCertificateBytes);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return listEquals(cert.der, trustedCertificateBytes);
      };
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final certData = await rootBundle.load('assets/server.crt');
    HttpOverrides.global = PinnedCertificateHttpOverrides(certData.buffer.asUint8List());
  } catch (e) {
    debugPrint('Could not load pinned certificate: $e');
  }

  // Initialize services
  final mediaHandler = MediaHandler();
  await mediaHandler.init();

  final serverClient = ServerClient(mediaHandler: mediaHandler);
  await serverClient.init();

  final audioPlayerService = AudioPlayerService();
  audioPlayerService.serverClient = serverClient;
  await audioPlayerService.init();

  // Desktop window setup
  if (isDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      minimumSize: Size(1200, 800),
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.maximize();
      await windowManager.setResizable(false);
      await windowManager.show();
    });
  }

  final themeService = ThemeService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AudioPlayerService>.value(value: audioPlayerService),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
      ],
      child: LyreApp(
        mediaHandler: mediaHandler,
        serverClient: serverClient,
      ),
    ),
  );
}

class LyreApp extends StatelessWidget {
  final MediaHandler mediaHandler;
  final ServerClient serverClient;

  const LyreApp({
    Key? key,
    required this.mediaHandler,
    required this.serverClient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<ThemeService>().themeColor;

    return MaterialApp(
      title: 'Lyre',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: themeColor,
        colorScheme: ColorScheme.dark(
          primary: themeColor,
          surface: const Color(0xFF000000),
        ),
        fontFamily: Platform.isMacOS
            ? '.AppleSystemUIFont'
            : 'Segoe UI',
      ),
      home: SplashScreen(
        nextScreen: serverClient.registered()
            ? (isDesktop
                ? DesktopWrapper(
                    mediaHandler: mediaHandler,
                    serverClient: serverClient,
                  )
                : MobileHomeScreen(
                    mediaHandler: mediaHandler,
                    serverClient: serverClient,
                    appDataPath: mediaHandler.appDataPath,
                  ))
            : LoginScreen(
                mediaHandler: mediaHandler,
                serverClient: serverClient,
              ),
      ),
    );
  }
}

/// Desktop wrapper adds global keyboard shortcuts (Spacebar -> play/pause)
class DesktopWrapper extends StatefulWidget {
  final MediaHandler mediaHandler;
  final ServerClient serverClient;

  const DesktopWrapper({
    Key? key,
    required this.mediaHandler,
    required this.serverClient,
  }) : super(key: key);

  @override
  State<DesktopWrapper> createState() => _DesktopWrapperState();
}

class _DesktopWrapperState extends State<DesktopWrapper> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _isInteractiveFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    
    // If a specific interactive element (button, checkbox, text field) has focus,
    // its focus node is typically a standard FocusNode, whereas the root or 
    // container scopes are FocusScopeNodes.
    if (focus is! FocusScopeNode) {
      return true;
    }
    return false;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      if (!mounted || _isInteractiveFocused()) {
        return false;
      }
      final audioService = Provider.of<AudioPlayerService>(context, listen: false);
      if (audioService.isPlaying) {
        audioService.pause();
      } else {
        audioService.resume();
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      mediaHandler: widget.mediaHandler,
      serverClient: widget.serverClient,
    );
  }
}
