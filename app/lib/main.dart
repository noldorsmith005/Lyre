import 'dart:io';
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
import 'utils/platform_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final mediaHandler = MediaHandler();
  await mediaHandler.init();

  final serverClient = ServerClient(mediaHandler: mediaHandler);
  await serverClient.init();

  final audioPlayerService = AudioPlayerService();

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
      home: serverClient.registered()
          ? (isDesktop
              ? _DesktopWrapper(
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
    );
  }
}

/// Desktop wrapper adds global keyboard shortcuts (Spacebar = play/pause)
class _DesktopWrapper extends StatelessWidget {
  final MediaHandler mediaHandler;
  final ServerClient serverClient;

  const _DesktopWrapper({
    required this.mediaHandler,
    required this.serverClient,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
          final audioService = Provider.of<AudioPlayerService>(context, listen: false);
          if (audioService.isPlaying) {
            audioService.pause();
          } else {
            audioService.resume();
          }
        }
      },
      child: HomeScreen(
        mediaHandler: mediaHandler,
        serverClient: serverClient,
      ),
    );
  }
}
