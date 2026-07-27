import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_player_service.dart';
import '../services/theme_service.dart';
import '../utils/layout_constants.dart';
import '../models/track.dart';

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

  @override
  Widget build(BuildContext context) {
    final audioService = context.watch<AudioPlayerService>();
    final currentTrack = audioService.currentTrack;

    final appDataPath = audioService.appDataPath;

    return Container(
      width: LayoutConstants.coverSize + 60, // approximate width
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(left: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
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
                                  child: currentTrack != null && appDataPath != null
                                      ? Image.file(
                                          File('$appDataPath/cover/${currentTrack.trackID}.jpg'),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.music_note, color: Colors.white54, size: 24),
                                        )
                                      : const Icon(Icons.music_note, color: Colors.white54, size: 24),
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
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: LayoutConstants.coverSize,
                            height: LayoutConstants.coverSize,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF555555), width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: currentTrack != null && appDataPath != null
                                  ? Image.file(
                                      File('$appDataPath/cover/${currentTrack.trackID}.jpg'),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.music_note, color: Colors.white54, size: 64),
                                    )
                                  : const Icon(Icons.music_note, color: Colors.white54, size: 64),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
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
                    const SizedBox(height: 8),
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
                  ],
                  const SizedBox(height: 24),
                  
                  // Seek Bar
                  StreamBuilder<Duration>(
                    stream: audioService.positionStream,
                    builder: (context, posSnapshot) {
                      return StreamBuilder<Duration?>(
                        stream: audioService.durationStream,
                        builder: (context, durSnapshot) {
                          final position = posSnapshot.data ?? Duration.zero;
                          final duration = durSnapshot.data ?? Duration.zero;
                          
                          double progress = 0.0;
                          if (duration.inMilliseconds > 0) {
                            progress = position.inMilliseconds / duration.inMilliseconds;
                          }

                          return Row(
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: const Color(0xFF444444),
                                    thumbColor: Colors.white,
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  ),
                                  child: Slider(
                                    value: progress.clamp(0.0, 1.0),
                                    onChanged: (val) {
                                      audioService.seek(val);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
                              ),
                            ],
                          );
                        }
                      );
                    }
                  ),
                  const SizedBox(height: 24),
                  
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _HoverIconButton(
                        iconPath: 'assets/prev.png',
                        size: 25,
                        onTap: () {
                          // audioService.previous()
                        },
                      ),
                      const SizedBox(width: 24),
                      _HoverIconButton(
                        iconPath: audioService.isPlaying ? 'assets/pause.png' : 'assets/play.png',
                        size: 25,
                        onTap: () {
                          if (audioService.isPlaying) {
                            audioService.pause();
                          } else {
                            audioService.resume();
                          }
                        },
                      ),
                      const SizedBox(width: 24),
                      _HoverIconButton(
                        iconPath: 'assets/next.png',
                        size: 25,
                        onTap: () {
                          audioService.next();
                        },
                      ),
                      const SizedBox(width: 24),
                      _HoverIconButton(
                        iconPath: 'assets/loop.png',
                        size: 26,
                        color: audioService.loop ? context.watch<ThemeService>().themeColor : Colors.white,
                        onTap: () {
                          audioService.loop = !audioService.loop;
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Queue section
          if (audioService.queue.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  SizedBox(
                    height: 300, // Fixed height or could be flexible
                    child: ListView.builder(
                      itemCount: audioService.queue.length,
                      itemBuilder: (context, index) {
                        final track = audioService.queue[index];
                        return _QueueCard(
                          track: track,
                          onRemove: () => audioService.removeFromQueue(track),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          color: _isHovered ? const Color(0xFF1C1C1C) : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(10),
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
  final String iconPath;
  final String? hoverIconPath;
  final double size;
  final VoidCallback onTap;
  final Color? color;

  const _HoverIconButton({
    required this.iconPath,
    this.hoverIconPath,
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
    final currentPath = (_isHovered && widget.hoverIconPath != null)
        ? widget.hoverIconPath!
        : widget.iconPath;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Opacity(
            opacity: (_isHovered && widget.hoverIconPath == null) ? 0.7 : 1.0,
            child: Image.asset(
              currentPath,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              color: widget.color ?? Colors.white,
              errorBuilder: (context, error, stackTrace) =>
                  SizedBox(width: widget.size, height: widget.size),
            ),
          ),
        ),
      ),
    );
  }
}
