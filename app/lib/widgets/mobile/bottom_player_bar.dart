import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/theme_service.dart';
import '../../screens/mobile/full_player_screen.dart';
import '../track_cover_image.dart';

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

    final themeColor = context.watch<ThemeService>().themeColor;

    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: false,
            backgroundColor: Colors.transparent,
            builder: (context) => FullPlayerScreen(appDataPath: appDataPath),
          );
        },
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF14141E), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'mobile_player_cover_${currentTrack.trackID}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: TrackCoverImage(
                              trackID: currentTrack.trackID,
                              appDataPath: appDataPath,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              fallback: Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFF22222E),
                                child: const Icon(Icons.music_note, color: Color(0xFF666677), size: 22),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentTrack.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9999AA),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            audioService.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            if (audioService.isPlaying) {
                              audioService.pause();
                            } else {
                              audioService.resume();
                            }
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
                          minHeight: 2.5,
                          backgroundColor: const Color(0xFF2B2B38),
                          valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                        );
                      }
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
