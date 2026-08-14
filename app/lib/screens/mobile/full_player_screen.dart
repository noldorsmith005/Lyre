import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/track_cover_image.dart';
import '../../widgets/mobile/mobile_queue_modal.dart';



class FullPlayerScreen extends StatelessWidget {
  final String appDataPath;

  const FullPlayerScreen({super.key, required this.appDataPath});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final remainingSeconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);
    final currentTrack = audioService.currentTrack;

    if (currentTrack == null) {
      return Container(color: const Color(0xFF0F0F0F));
    }

    final topInset = MediaQuery.of(context).viewPadding.top;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topInset > 0 ? 16 : 24),
            // Cover Art
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Hero(
                      tag: 'mobile_player_cover_${currentTrack.trackID}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: TrackCoverImage(
                            trackID: currentTrack.trackID,
                            appDataPath: appDataPath,
                            fit: BoxFit.cover,
                            fallback: Image.asset(
                              'assets/default.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Title & Artist
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    currentTrack.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentTrack.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF888888)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Seek bar
            _SeekBar(audioService: audioService),
            const SizedBox(height: 16),
            
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shuffle
                IconButton(
                  iconSize: 26,
                  icon: const Icon(CupertinoIcons.shuffle),
                  color: audioService.shuffle ? context.watch<ThemeService>().themeColor : Colors.white,
                  onPressed: () {
                    audioService.setShuffle();
                  },
                ),
                const SizedBox(width: 16),
                // Previous
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.skip_previous),
                  color: Colors.white,
                  onPressed: () => audioService.seek(0.0),
                ),
                const SizedBox(width: 16),
                // Play/Pause
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 40,
                    icon: Icon(audioService.isPlaying ? Icons.pause : Icons.play_arrow),
                    color: Colors.black,
                    onPressed: () {
                      if (audioService.isPlaying) {
                        audioService.pause();
                      } else {
                        audioService.resume();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Next
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.skip_next),
                  color: Colors.white,
                  onPressed: () => audioService.next(),
                ),
                const SizedBox(width: 16),
                // Loop
                IconButton(
                  iconSize: 26,
                  icon: const Icon(Icons.repeat),
                  color: audioService.loop ? context.watch<ThemeService>().themeColor : Colors.white,
                  onPressed: () {
                    audioService.toggleLoop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Queue Button / Bottom Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => MobileQueueModal.show(context, appDataPath: appDataPath),
                    icon: Icon(
                      Icons.queue_music_rounded,
                      color: context.watch<ThemeService>().themeColor,
                      size: 22,
                    ),
                    label: const Text(
                      'Queue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      side: const BorderSide(color: Color(0xFF333344), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      backgroundColor: const Color(0xFF181822),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  final AudioPlayerService audioService;
  const _SeekBar({required this.audioService});

  @override
  _SeekBarState createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final remainingSeconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.audioService.positionStream,
      builder: (context, posSnapshot) {
        final position = posSnapshot.data ?? Duration.zero;
        final duration = widget.audioService.currentTrackDuration;
        final durationMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
        final themeColor = context.watch<ThemeService>().themeColor;

        double currentPercent = (position.inMilliseconds / durationMs).clamp(0.0, 1.0);
        double displayPercent = _dragValue ?? currentPercent;
        
        Duration displayPosition = _dragValue != null 
          ? Duration(milliseconds: (_dragValue! * durationMs).round())
          : position;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(_formatDuration(displayPosition), style: const TextStyle(fontSize: 13, color: Color(0xFF888888), fontFeatures: [FontFeature.tabularFigures()])),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: themeColor,
                    inactiveTrackColor: const Color(0xFF333333),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 3),
                    overlayColor: themeColor.withValues(alpha: 0.2),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: displayPercent,
                    onChangeStart: (val) {
                      setState(() {
                        _dragValue = val;
                      });
                    },
                    onChanged: (val) {
                      setState(() {
                        _dragValue = val;
                      });
                    },
                    onChangeEnd: (val) {
                      widget.audioService.seek(val);
                      setState(() {
                        _dragValue = null;
                      });
                    },
                  ),
                ),
              ),
              Text(_formatDuration(duration), style: const TextStyle(fontSize: 13, color: Color(0xFF888888), fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
        );
      },
    );
  }
}
