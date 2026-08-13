import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../services/theme_service.dart';
import '../utils/layout_constants.dart';
import 'play_bars.dart';
import 'confirmation_dialog.dart';
import 'track_cover_image.dart';



class TrackCard extends StatefulWidget {
  final Track track;
  final bool isDownloaded;
  final bool isDownloading;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onRemoveDownload;
  final VoidCallback? onQueue;
  final List<Playlist> availablePlaylists;
  final Function(Playlist, Track) onTogglePlaylist;
  final bool Function(Playlist, Track) isTrackInPlaylist;
  final String appDataPath;
  final bool isServerConnected;

  const TrackCard({
    super.key,
    required this.track,
    required this.isDownloaded,
    this.isDownloading = false,
    required this.isPlaying,
    required this.onPlay,
    this.onDownload,
    this.onRemoveDownload,
    this.onQueue,
    required this.availablePlaylists,
    required this.onTogglePlaylist,
    required this.isTrackInPlaylist,
    required this.appDataPath,
    this.isServerConnected = true,
  });

  @override
  _TrackCardState createState() => _TrackCardState();
}

class _TrackCardState extends State<TrackCard> {
  bool _isHovered = false;

  void _showPlaylistPopup(BuildContext context, Offset position) {
    final themeColor = Provider.of<ThemeService>(context, listen: false).themeColor;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + 20,
        position.dx + 220,
        position.dy + 220,
      ),
      color: const Color(0xEE1E1E26),
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF2E2E3A), width: 1),
      ),
      menuPadding: EdgeInsets.zero,
      items: [
        _PlaylistMenuContent(
          availablePlaylists: widget.availablePlaylists,
          track: widget.track,
          onTogglePlaylist: widget.onTogglePlaylist,
          isTrackInPlaylist: widget.isTrackInPlaylist,
          themeColor: themeColor,
        ),
      ],
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: LayoutConstants.cellSize,
          padding: EdgeInsets.symmetric(
            vertical: LayoutConstants.paddingV,
            horizontal: LayoutConstants.paddingH,
          ),
          margin: EdgeInsets.only(bottom: LayoutConstants.cellSpacing),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF1A1A1A)
                : (widget.isPlaying ? const Color(0xFF141414) : const Color(0xFF080808)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered ? const Color(0xFF2A2A2A) : const Color(0xFF141414),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Center(
                  child: widget.isDownloading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(context.watch<ThemeService>().themeColor),
                          ),
                        )
                      : widget.isDownloaded
                          ? _buildTooltip(
                              message: 'Play',
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: widget.onPlay,
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 22,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : _buildTooltip(
                              message: 'Download',
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: widget.onDownload ?? () {},
                                  child: Icon(
                                    Icons.file_download_outlined,
                                    size: 22,
                                    color: context.watch<ThemeService>().themeColor,
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Thumb
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TrackCoverImage(
                  trackID: widget.track.trackID,
                  appDataPath: widget.appDataPath,
                  width: LayoutConstants.thumbSize,
                  height: LayoutConstants.thumbSize,
                  fit: BoxFit.cover,
                  fallback: _buildFallbackThumb(),
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
                        color: widget.isPlaying
                            ? context.watch<ThemeService>().themeColor
                            : (widget.isDownloaded ? Colors.white : const Color(0xFF757588)),
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
                        color: const Color(0xFFB3B3B3),
                        fontSize: LayoutConstants.subFontSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Equalizer bar horizontally centered between title/thumb and duration/actions
              Expanded(
                child: Center(
                  child: widget.isPlaying
                      ? PlayBars(
                          barCount: 12,
                          maxHeight: 28.0,
                          minHeight: 4.0,
                          barWidth: 4.5,
                          barSpacing: 3.5,
                          isPlaying: widget.isPlaying,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              
              if (widget.isDownloaded) ...[
              _buildTooltip(
                message: 'Add to Queue',
                child: _HoverIconButton(
                  icon: Icons.playlist_add_rounded,
                  size: 22,
                  color: Colors.white,
                  onTap: widget.onQueue ?? () {},
                ),
              ),
              const SizedBox(width: 16),

              Builder(
                builder: (ctx) => _buildTooltip(
                  message: 'Add to Playlist',
                  child: _HoverIconButton(
                    icon: Icons.add_circle_outline_rounded,
                    size: 22,
                    color: Colors.white,
                    onTap: () {
                      final renderBox = ctx.findRenderObject() as RenderBox;
                      final position = renderBox.localToGlobal(Offset.zero);
                      _showPlaylistPopup(context, position);
                    },
                  ),
                ),
              ),
              if (widget.isServerConnected && widget.onRemoveDownload != null) ...[
                const SizedBox(width: 16),
                _buildTooltip(
                  message: 'Remove Download',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () async {
                        final confirmed = await ConfirmationDialog.show(
                          context,
                          title: 'Remove Download',
                          message: 'Are you sure you want to remove "${widget.track.title}" from your local downloads?',
                          confirmText: 'Remove',
                        );
                        if (confirmed == true && widget.onRemoveDownload != null) {
                          widget.onRemoveDownload!();
                        }
                      },
                      child: const Icon(
                        Icons.delete_outline,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
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

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final VoidCallback onTap;

  const _HoverIconButton({
    required this.icon,
    required this.size,
    this.color,
    required this.onTap,
  });

  @override
  _HoverIconButtonState createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: _isHovered ? 0.7 : 1.0,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PlaylistMenuContent extends PopupMenuEntry<Never> {
  final List<Playlist> availablePlaylists;
  final Track track;
  final Function(Playlist, Track) onTogglePlaylist;
  final bool Function(Playlist, Track) isTrackInPlaylist;
  final Color themeColor;

  const _PlaylistMenuContent({
    required this.availablePlaylists,
    required this.track,
    required this.onTogglePlaylist,
    required this.isTrackInPlaylist,
    required this.themeColor,
  });

  @override
  double get height {
    if (availablePlaylists.isEmpty) return 48.0;
    return (availablePlaylists.length * 44.0).clamp(44.0, 240.0);
  }

  @override
  bool represents(Never? value) => false;

  @override
  State<_PlaylistMenuContent> createState() => _PlaylistMenuContentState();
}

class _PlaylistMenuContentState extends State<_PlaylistMenuContent> {
  late final Set<int> _inPlaylistIds;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _inPlaylistIds = widget.availablePlaylists
        .where((pl) => widget.isTrackInPlaylist(pl, widget.track))
        .map((pl) => pl.playlistID)
        .toSet();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggle(Playlist playlist) {
    setState(() {
      if (_inPlaylistIds.contains(playlist.playlistID)) {
        _inPlaylistIds.remove(playlist.playlistID);
      } else {
        _inPlaylistIds.add(playlist.playlistID);
      }
    });
    widget.onTogglePlaylist(playlist, widget.track);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.availablePlaylists.isEmpty) {
      return const SizedBox(
        width: 220,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            'No playlists available',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 240,
        minWidth: 220,
        maxWidth: 260,
      ),
      child: RawScrollbar(
        controller: _scrollController,
        thumbColor: Colors.white24,
        radius: const Radius.circular(4),
        thickness: 4,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < widget.availablePlaylists.length; i++)
                _PlaylistRowItem(
                  playlist: widget.availablePlaylists[i],
                  inPlaylist: _inPlaylistIds.contains(widget.availablePlaylists[i].playlistID),
                  themeColor: widget.themeColor,
                  isLast: i == widget.availablePlaylists.length - 1,
                  onTap: () => _toggle(widget.availablePlaylists[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistRowItem extends StatefulWidget {
  final Playlist playlist;
  final bool inPlaylist;
  final Color themeColor;
  final bool isLast;
  final VoidCallback onTap;

  const _PlaylistRowItem({
    required this.playlist,
    required this.inPlaylist,
    required this.themeColor,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_PlaylistRowItem> createState() => _PlaylistRowItemState();
}

class _PlaylistRowItemState extends State<_PlaylistRowItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFF2A2A38) : Colors.transparent,
            border: widget.isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: Color(0xFF2E2E3A), width: 1),
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.playlist.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.inPlaylist ? widget.themeColor : const Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
