import 'dart:io';
import 'package:flutter/material.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../utils/layout_constants.dart';
import 'play_bars.dart';

class TrackCard extends StatefulWidget {
  final Track track;
  final bool isDownloaded;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onQueue;
  final List<Playlist> availablePlaylists;
  final Function(Playlist, Track) onTogglePlaylist;
  final bool Function(Playlist, Track) isTrackInPlaylist;
  final String appDataPath;

  const TrackCard({
    Key? key,
    required this.track,
    required this.isDownloaded,
    required this.isPlaying,
    required this.onPlay,
    this.onDownload,
    this.onQueue,
    required this.availablePlaylists,
    required this.onTogglePlaylist,
    required this.isTrackInPlaylist,
    required this.appDataPath,
  }) : super(key: key);

  @override
  _TrackCardState createState() => _TrackCardState();
}

class _TrackCardState extends State<TrackCard> {
  bool _isHovered = false;

  void _showPlaylistPopup(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + 20,
        position.dx + 200,
        position.dy + 200,
      ),
      color: const Color(0xFF2B2B2B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      items: widget.availablePlaylists.map((playlist) {
        final isInPlaylist = widget.isTrackInPlaylist(playlist, widget.track);
        return PopupMenuItem<Playlist>(
          value: playlist,
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (context, setPopupState) {
              final inPlaylist = widget.isTrackInPlaylist(playlist, widget.track);
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    widget.onTogglePlaylist(playlist, widget.track);
                    setPopupState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF3C3F41), width: 1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            playlist.title,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: inPlaylist ? const Color(0xFFFF0000) : const Color(0xFF7F8C8D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTooltip({required Widget child, required String message}) {
    return Tooltip(
      message: message,
      waitDuration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: Colors.white),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildTooltip(
      message: widget.track.title,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
        height: LayoutConstants.cellSize,
        padding: EdgeInsets.symmetric(
          vertical: LayoutConstants.paddingV,
          horizontal: LayoutConstants.paddingH,
        ),
        margin: EdgeInsets.only(bottom: LayoutConstants.cellSpacing),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF0F0F0F) : Colors.transparent,
          border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            if (widget.isDownloaded) ...[
              _buildTooltip(
                message: 'Play',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onPlay,
                    child: Image.asset(
                      'assets/play.png',
                      width: 12,
                      height: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ] else ...[
              _buildTooltip(
                message: 'Download',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onDownload,
                    child: Image.asset(
                      'assets/download.png',
                      width: 22,
                      height: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 16),
            
            // Thumb
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                      File('${widget.appDataPath}/cover/${widget.track.trackID}.jpg'),
                      width: LayoutConstants.thumbSize,
                      height: LayoutConstants.thumbSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackThumb(),
                    ),
            ),
            const SizedBox(width: 16),
            
            // Title and Artist
            SizedBox(
              width: LayoutConstants.trackCardTextSize,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.track.title,
                    style: TextStyle(
                      color: widget.isPlaying ? const Color(0xFFFF0000) : Colors.white,
                      fontSize: LayoutConstants.titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.track.artist,
                    style: TextStyle(
                      color: const Color(0xFF555555),
                      fontSize: LayoutConstants.subFontSize,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            if (widget.isPlaying) ...[
              const SizedBox(width: 12),
              const PlayBars(),
            ],
            
            const Spacer(),
            
            if (widget.isDownloaded) ...[
              _buildTooltip(
                message: 'Add to Queue',
                child: _HoverImageAssetButton(
                  iconPath: 'assets/add_to_queue.png',
                  hoverIconPath: 'assets/add_to_queue_hover.png',
                  size: 16,
                  color: const Color(0xFFB3B3B3),
                  onTap: widget.onQueue ?? () {},
                ),
              ),
              const SizedBox(width: 16),
              
              Builder(
                builder: (ctx) => _buildTooltip(
                  message: 'Add to Playlist',
                  child: _HoverImageAssetButton(
                    iconPath: 'assets/add_to_playlist.png',
                    hoverIconPath: 'assets/add_to_playlist_hover.png',
                    size: 16,
                    color: const Color(0xFFB3B3B3),
                    onTap: () {
                      final renderBox = ctx.findRenderObject() as RenderBox;
                      final position = renderBox.localToGlobal(Offset.zero);
                      _showPlaylistPopup(context, position);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20),
              
              Text(
                widget.track.duration,
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 14,
                ),
              ),
            ] else ...[
              Text(
                widget.track.contributor.isNotEmpty ? 'Uploaded by: ${widget.track.contributor}' : '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
  
  Widget _buildFallbackThumb() {
    return Container(
      width: LayoutConstants.thumbSize,
      height: LayoutConstants.thumbSize,
      color: const Color(0xFF2A2A2A),
      child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
    );
  }
}

class _HoverImageAssetButton extends StatefulWidget {
  final String iconPath;
  final String? hoverIconPath;
  final double size;
  final Color? color;
  final VoidCallback onTap;

  const _HoverImageAssetButton({
    Key? key,
    required this.iconPath,
    this.hoverIconPath,
    required this.size,
    this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  _HoverImageAssetButtonState createState() => _HoverImageAssetButtonState();
}

class _HoverImageAssetButtonState extends State<_HoverImageAssetButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final path = (_isHovered && widget.hoverIconPath != null)
        ? widget.hoverIconPath!
        : widget.iconPath;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Image.asset(
          path,
          width: widget.size,
          height: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}
