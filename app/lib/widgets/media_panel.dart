import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_player_service.dart';
import '../services/theme_service.dart';
import '../utils/layout_constants.dart';
import '../models/track.dart';
import 'track_cover_image.dart';



class MediaPanel extends StatefulWidget {
  const MediaPanel({Key? key}) : super(key: key);

  @override
  State<MediaPanel> createState() => _MediaPanelState();
}

class _MediaPanelState extends State<MediaPanel> {
  bool _isCollapsed = false;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showCoverArtLightbox(BuildContext context, Track? track, String? appDataPath) {
    if (track == null || appDataPath == null) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.all(32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 550, maxHeight: 550),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: TrackCoverImage(
                    trackID: track.trackID,
                    appDataPath: appDataPath,
                    fit: BoxFit.contain,
                    fallback: Container(
                      width: 320,
                      height: 320,
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.music_note, color: Colors.white54, size: 80),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioPlayerService>();
    final currentTrack = audioService.currentTrack;

    final appDataPath = audioService.appDataPath;

    return Container(
      width: LayoutConstants.coverSize + 60, // approximate width
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(left: BorderSide(color: Color(0xFF282828), width: 1)),
      ),
      child: Column(
        children: [
          // Upper part (Cover, Title, Seek, Controls)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_isCollapsed)
                    // Collapsed state: Small card
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCollapsed = false;
                          });
                        },
                        child: Container(
                          width: LayoutConstants.coverSize,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            border: Border(
                              top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
                              bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.keyboard_arrow_right,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF444444), width: 1),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: TrackCoverImage(
                                    trackID: currentTrack?.trackID,
                                    appDataPath: appDataPath,
                                    fit: BoxFit.cover,
                                    fallback: const Icon(Icons.music_note, color: Colors.white54, size: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currentTrack?.title ?? 'No Track Playing',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentTrack?.artist ?? '',
                                      style: const TextStyle(
                                        color: Color(0xFF888888),
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else ...[
                    // Expanded state: Down chevron above & left of large cover art
                    SizedBox(
                      width: LayoutConstants.coverSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isCollapsed = true;
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(bottom: 8.0),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _showCoverArtLightbox(context, currentTrack, appDataPath),
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF555555), width: 1),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: TrackCoverImage(
                                      trackID: currentTrack?.trackID,
                                      appDataPath: appDataPath,
                                      fit: BoxFit.cover,
                                      fallback: const Icon(Icons.music_note, color: Colors.white54, size: 64),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Title and Artist
                    Text(
                      currentTrack?.title ?? 'No Track Playing',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentTrack?.artist ?? '',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),

                  // Seek Bar
                  _MediaPanelSeekBar(audioService: audioService),
                  const SizedBox(height: 8),
                  
                  // Controls: Play button aligned strictly in the horizontal center
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _HoverIconButton(
                              icon: Icons.skip_previous_rounded,
                              size: 46,
                              color: Colors.white,
                              onTap: () {
                                audioService.previous();
                              },
                            ),
                            const SizedBox(width: 24),
                          ],
                        ),
                      ),
                      _HoverIconButton(
                        icon: audioService.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 56,
                        color: Colors.white,
                        onTap: () {
                          if (audioService.isPlaying) {
                            audioService.pause();
                          } else {
                            audioService.resume();
                          }
                        },
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(width: 24),
                            _HoverIconButton(
                              icon: Icons.skip_next_rounded,
                              size: 46,
                              color: Colors.white,
                              onTap: () {
                                audioService.next();
                              },
                            ),
                            const SizedBox(width: 24),
                            _HoverIconButton(
                              icon: audioService.loop ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                              size: 32,
                              color: audioService.loop ? context.watch<ThemeService>().themeColor : Colors.white,
                              onTap: () {
                                audioService.toggleLoop();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  
                  // Queue section
                  if (audioService.queue.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.only(top: 20),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Next in Queue:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              _HoverTextButton(
                                text: 'Clear Queue',
                                onTap: () {
                                  audioService.clearQueue();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: audioService.queue.length,
                            itemBuilder: (context, index) {
                              final track = audioService.queue[index];
                              return _QueueCard(
                                track: track,
                                onRemove: () => audioService.removeFromQueue(track),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverTextButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _HoverTextButton({required this.text, required this.onTap});

  @override
  __HoverTextButtonState createState() => __HoverTextButtonState();
}

class __HoverTextButtonState extends State<_HoverTextButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          style: TextStyle(
            color: _isHovered ? const Color(0xFF555555) : Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _QueueCard extends StatefulWidget {
  final Track track;
  final VoidCallback onRemove;

  const _QueueCard({
    required this.track,
    required this.onRemove,
  });

  @override
  __QueueCardState createState() => __QueueCardState();
}

class __QueueCardState extends State<_QueueCard> {
  bool _isHovered = false;
  bool _isRemoveHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF1C1C28) : const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isHovered ? const Color(0xFF2E2E40) : const Color(0xFF1E1E2B),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.track.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: LayoutConstants.queueTitleFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.track.artist,
                    style: TextStyle(
                      color: const Color(0xFF888888),
                      fontSize: LayoutConstants.queueArtistFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.track.duration,
              style: TextStyle(
                color: const Color(0xFF555555),
                fontSize: LayoutConstants.queueDurationFontSize,
              ),
            ),
            const SizedBox(width: 12),
            MouseRegion(
              onEnter: (_) => setState(() => _isRemoveHovered = true),
              onExit: (_) => setState(() => _isRemoveHovered = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onRemove,
                child: Text(
                  '⛌',
                  style: TextStyle(
                    color: _isRemoveHovered ? const Color(0xFF555555) : const Color(0xFFE8E8E8),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final Color? color;

  const _HoverIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.color,
  });

  @override
  __HoverIconButtonState createState() => __HoverIconButtonState();
}

class __HoverIconButtonState extends State<_HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Icon(
              widget.icon,
              size: widget.size,
              color: widget.color ?? Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaPanelSeekBar extends StatefulWidget {
  final AudioPlayerService audioService;
  const _MediaPanelSeekBar({required this.audioService});

  @override
  _MediaPanelSeekBarState createState() => _MediaPanelSeekBarState();
}

class _MediaPanelSeekBarState extends State<_MediaPanelSeekBar> {
  double? _dragValue;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.audioService.positionStream,
      builder: (context, posSnapshot) {
        final position = posSnapshot.data ?? Duration.zero;
        final duration = widget.audioService.currentTrackDuration;
        final durationMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
        
        double currentPercent = (position.inMilliseconds / durationMs).clamp(0.0, 1.0);
        double displayPercent = _dragValue ?? currentPercent;
        
        Duration displayPosition = _dragValue != null 
          ? Duration(milliseconds: (_dragValue! * durationMs).round())
          : position;

        final themeColor = context.watch<ThemeService>().themeColor;

        return Row(
          children: [
            Text(
              _formatDuration(displayPosition),
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: themeColor,
                  inactiveTrackColor: const Color(0xFF262626),
                  thumbColor: Colors.white,
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                    elevation: 3,
                    pressedElevation: 6,
                  ),
                  overlayColor: themeColor.withOpacity(0.2),
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
            const SizedBox(width: 8),
            Text(
              _formatDuration(duration),
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      }
    );
  }
}
