import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/track.dart';
import '../../services/theme_service.dart';
import '../play_bars.dart';
import '../track_cover_image.dart';



class MobileTrackRow extends StatefulWidget {
  final Track track;
  final bool isPlaying;
  final bool isDownloading;
  final bool isServerConnected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onQueue;
  final VoidCallback? onDownloadTrack;
  final VoidCallback? onRemoveDownloadTrack;
  final String appDataPath;

  const MobileTrackRow({
    super.key,
    required this.track,
    required this.isPlaying,
    this.isDownloading = false,
    this.isServerConnected = false,
    required this.onTap,
    required this.onLongPress,
    required this.onQueue,
    this.onDownloadTrack,
    this.onRemoveDownloadTrack,
    required this.appDataPath,
  });

  @override
  State<MobileTrackRow> createState() => _MobileTrackRowState();
}

class _MobileTrackRowState extends State<MobileTrackRow> {
  double _dragOffset = 0.0;

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0.0;
    if (delta > 0 || _dragOffset > 0) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(0.0, 130.0);
      });
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset >= 40.0) {
      HapticFeedback.mediumImpact();
      widget.onQueue();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to queue', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1E1E28),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    setState(() {
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<ThemeService>().themeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
      child: GestureDetector(
        onTap: widget.track.downloaded ? widget.onTap : null,
        onHorizontalDragUpdate: widget.track.downloaded ? _onDragUpdate : null,
        onHorizontalDragEnd: widget.track.downloaded ? _onDragEnd : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Background queue indicator
            Positioned.fill(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF161620),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.queue_music, color: themeColor, size: 24),
              ),
            ),
            // Sliding card content
            AnimatedContainer(
              duration: _dragOffset == 0.0 ? const Duration(milliseconds: 200) : Duration.zero,
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(_dragOffset, 0, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: widget.isPlaying ? const Color(0xFF0C0C12) : const Color(0xFF06060A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF14141E),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    // Leading: Downloading indicator (if downloading), Download button (if non-downloaded), PlayBars (if playing), or Cover Art
                    if (widget.isDownloading)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141422),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                            ),
                          ),
                        ),
                      )
                    else if (!widget.track.downloaded)
                      GestureDetector(
                        onTap: widget.onDownloadTrack,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF141422),
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.file_download_outlined,
                              color: themeColor,
                              size: 22,
                            ),
                          ),
                        ),
                      )
                    else if (widget.isPlaying)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141422),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Center(
                          child: PlayBars(
                            barCount: 4,
                            maxHeight: 20.0,
                            minHeight: 4.0,
                            barWidth: 3.0,
                            barSpacing: 2.5,
                            isPlaying: true,
                          ),
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6.0),
                        child: TrackCoverImage(
                          trackID: widget.track.trackID,
                          appDataPath: widget.appDataPath,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          fallback: Image.asset(
                            'assets/default.jpg',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 44,
                              height: 44,
                              color: const Color(0xFF1B1B26),
                              child: const Icon(Icons.music_note, color: Color(0xFF757588), size: 20),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),

                    // Title & Artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.isPlaying
                                  ? themeColor
                                  : (widget.track.downloaded ? Colors.white : const Color(0xFF757588)),
                              fontWeight: widget.isPlaying ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB3B3C3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Action area: Downloaded controls or Contributor text
                    if (widget.track.downloaded) ...[
                      // Playlist Add button
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF888899), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'Add to Playlist',
                        onPressed: widget.onLongPress,
                      ),
                      if (widget.isServerConnected && widget.onRemoveDownloadTrack != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFF888899), size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Remove Download',
                          onPressed: widget.onRemoveDownloadTrack,
                        ),
                      ],
                      const SizedBox(width: 4),

                      // Track duration
                      Text(
                        widget.track.duration,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757588),
                        ),
                      ),
                    ] else ...[
                      // Contributor display for non-downloaded tracks
                      if (widget.track.contributor.isNotEmpty)
                        Text(
                          widget.track.contributor,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF757588),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

