import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/theme_service.dart';
import '../../screens/mobile/full_player_screen.dart';

class BottomPlayerBar extends StatelessWidget {
  final String appDataPath;

  const BottomPlayerBar({Key? key, required this.appDataPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);
    final currentTrack = audioService.currentTrack;

    if (currentTrack == null) {
      return const SizedBox.shrink();
    }

    final coverFile = File('$appDataPath/cover/${currentTrack.trackID}.jpg');
    final hasCover = coverFile.existsSync();

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => FullPlayerScreen(appDataPath: appDataPath),
        );
      },
      child: Container(
        height: 66, // 64 + 2 for progress
        color: const Color(0xFF161616),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: hasCover
                          ? Image.file(
                              coverFile,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              color: const Color(0xFF1E1E1E),
                              child: const Icon(Icons.music_note, color: Color(0xFF555555), size: 20),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentTrack.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentTrack.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (audioService.isPlaying) {
                          audioService.pause();
                        } else {
                          audioService.resume();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      onPressed: () {
                        audioService.next();
                      },
                    ),
                  ],
                ),
              ),
            ),
            StreamBuilder<Duration>(
              stream: audioService.positionStream,
              builder: (context, snapshot) {
                return StreamBuilder<Duration?>(
                  stream: audioService.durationStream,
                  builder: (context, durationSnapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = durationSnapshot.data ?? const Duration(seconds: 1);
                    
                    double progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;
                    
                    if (progress > 1.0) progress = 1.0;
                    if (progress < 0.0) progress = 0.0;

                      return LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: const Color(0xFF333333),
                        valueColor: AlwaysStoppedAnimation<Color>(context.watch<ThemeService>().themeColor),
                      );
                  }
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
