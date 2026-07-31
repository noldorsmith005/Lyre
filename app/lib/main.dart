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



class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    if (kDebugMode) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) =>
              host == '127.0.0.1' || host == 'localhost';
    }
    return client;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

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

  bool _isEditingText() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null) return false;
    final context = focus.context!;

    final widget = context.widget;
    if (widget is EditableText ||
        widget is TextField ||
        widget is TextFormField) {
      return true;
    }

    if (context.findAncestorStateOfType<EditableTextState>() != null ||
        context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorWidgetOfExactType<TextField>() != null ||
        context.findAncestorWidgetOfExactType<TextFormField>() != null) {
      return true;
    }

    bool isEditing = false;
    if (context is Element) {
      context.visitAncestorElements((ancestor) {
        final w = ancestor.widget;
        if (w is EditableText ||
            w is TextField ||
            w is TextFormField) {
          isEditing = true;
          return false;
        }
        return true;
      });
    }
    return isEditing;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      if (!mounted || _isEditingText()) {
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
