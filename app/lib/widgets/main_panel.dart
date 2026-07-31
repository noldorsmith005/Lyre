import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../screens/settings_screen.dart';
import '../services/theme_service.dart';
import '../services/audio_player_service.dart';
import '../services/server_client.dart';
import '../utils/platform_utils.dart';
import 'track_card.dart';
import 'track_cover_image.dart';



class MainPanel extends StatefulWidget {
  final Playlist? currentPlaylist;
  final List<Track> tracks;
  final Function(String) onSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onRlsPressed;
  final VoidCallback onUploadPressed;
  final VoidCallback onClearConfigPressed;
  final VoidCallback? onPlaybackPressed;
  final VoidCallback? onVibeQueuePressed;
  final VoidCallback onShufflePressed;
  final Function(String) onEditPlaylistName;
  final VoidCallback onDeletePlaylist;
  final Track? playingTrack;
  final Function(Track) onPlayTrack;
  final Function(Track)? onDownloadTrack;
  final Function(Track)? onRemoveDownloadTrack;
  final Function(Track) onQueueTrack;
  final List<Playlist> availablePlaylists;
  final Function(Playlist, Track) onTogglePlaylist;
  final bool Function(Playlist, Track) isTrackInPlaylist;
  final bool isServerConnected;
  final ServerClient? serverClient;
  final Function(int oldIndex, int newIndex)? onReorderTrack;

  const MainPanel({
    Key? key,
    this.currentPlaylist,
    required this.tracks,
    required this.onSearch,
    required this.onClearSearch,
    required this.onRlsPressed,
    required this.onUploadPressed,
    required this.onClearConfigPressed,
    this.onPlaybackPressed,
    this.onVibeQueuePressed,
    required this.onShufflePressed,
    required this.onEditPlaylistName,
    required this.onDeletePlaylist,
    this.playingTrack,
    required this.onPlayTrack,
    this.onDownloadTrack,
    this.onRemoveDownloadTrack,
    required this.onQueueTrack,
    required this.availablePlaylists,
    required this.onTogglePlaylist,
    required this.isTrackInPlaylist,
    required this.isServerConnected,
    this.serverClient,
    this.onReorderTrack,
  }) : super(key: key);

  @override
  _MainPanelState createState() => _MainPanelState();
}

class _MainPanelState extends State<MainPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditPlaylistDialog() async {
    if (widget.currentPlaylist == null) return;
    
    final TextEditingController nameController = TextEditingController(text: widget.currentPlaylist!.title);
    final themeColor = Provider.of<ThemeService>(context, listen: false).themeColor;

    try {
      await showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        builder: (context) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 12,
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xEE18181E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2E2E3A), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Edit Playlist Name',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E1E26),
                        hintText: 'Playlist Title',
                        hintStyle: const TextStyle(color: Color(0xFF888888)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: themeColor, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2E2E3A), width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Color(0xFF3E2222)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onDeletePlaylist();
                          },
                          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            elevation: 4,
                            shadowColor: themeColor.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            widget.onEditPlaylistName(nameController.text);
                            Navigator.pop(context);
                          },
                          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      nameController.dispose();
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(bottom: BorderSide(color: Color(0xFF282828), width: 1)),
      ),
      child: Row(
        children: [
          // Pill Search Bar
          _SearchBar(
            controller: _searchController,
            onSearch: widget.onSearch,
            onClearSearch: widget.onClearSearch,
          ),
          if (showServerFeatures) ...[
            const SizedBox(width: 16),
            Tooltip(
              message: 'Connect to RLS',
              child: _HoverIconButton(
                icon: Icons.cloud_outlined,
                size: 34,
                color: widget.isServerConnected
                    ? Provider.of<ThemeService>(context).themeColor
                    : Colors.white,
                onTap: widget.onRlsPressed,
              ),
            ),
          ],
          const Spacer(),
          
          if (showServerFeatures) ...[
            _AccountMenuButton(
              onUploadPressed: widget.onUploadPressed,
              onClearConfigPressed: widget.onClearConfigPressed,
              onPlaybackPressed: widget.onPlaybackPressed,
              onVibeQueuePressed: widget.onVibeQueuePressed,
              isServerConnected: widget.isServerConnected,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(bottom: BorderSide(color: Color(0xFF282828), width: 1)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.currentPlaylist?.title ?? 'All Songs',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.currentPlaylist != null) ...[
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: _showEditPlaylistDialog,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB3B3B3),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      child: const Text('Edit Playlist'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.tracks.length} tracks',
                style: const TextStyle(
                  color: Color(0xFFB3B3B3),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Spacer(),
          Builder(
            builder: (context) {
              final isShuffled = context.watch<AudioPlayerService>().shuffle;
              final themeColor = context.watch<ThemeService>().themeColor;
              return Tooltip(
                message: 'Shuffle',
                child: _HoverIconButton(
                  icon: Icons.shuffle_rounded,
                  size: 34,
                  color: isShuffled ? themeColor : Colors.white,
                  onTap: widget.onShufflePressed,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF000000),
      child: Column(
        children: [
          _buildTopBar(),
          _buildHeaderRow(),
          Expanded(
            child: ValueListenableBuilder<Set<int>>(
              valueListenable: widget.serverClient?.downloadingTrackIdsNotifier ?? ValueNotifier<Set<int>>({}),
              builder: (context, downloadingIds, child) {
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.tracks.length,
                  itemBuilder: (context, index) {
                    final track = widget.tracks[index];
                    final isPlaying = widget.playingTrack?.trackID == track.trackID;
                    final isDownloading = downloadingIds.contains(track.trackID);
                    final appDataPath = Provider.of<AudioPlayerService>(context, listen: false).appDataPath ?? '';
                    final card = TrackCard(
                      track: track,
                      isDownloaded: track.downloaded,
                      isDownloading: isDownloading,
                      isPlaying: isPlaying,
                      onPlay: () => widget.onPlayTrack(track),
                      onDownload: widget.onDownloadTrack != null ? () => widget.onDownloadTrack!(track) : null,
                      onRemoveDownload: widget.onRemoveDownloadTrack != null ? () => widget.onRemoveDownloadTrack!(track) : null,
                      onQueue: () => widget.onQueueTrack(track),
                      availablePlaylists: widget.availablePlaylists,
                      onTogglePlaylist: widget.onTogglePlaylist,
                      isTrackInPlaylist: widget.isTrackInPlaylist,
                      appDataPath: appDataPath,
                      isServerConnected: widget.isServerConnected,
                    );

                    if (isDesktop && widget.onReorderTrack != null) {
                      return _DraggableTrackItem(
                        index: index,
                        track: track,
                        onReorder: widget.onReorderTrack!,
                        appDataPath: appDataPath,
                        child: card,
                      );
                    }
                    return card;
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final VoidCallback onClearSearch;

  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.onClearSearch,
  });

  @override
  _SearchBarState createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 360,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: Colors.white,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onSearch,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  widget.controller.clear();
                  widget.onClearSearch();
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.close_rounded,
                    color: Color(0xFFB3B3B3),
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
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

class _AccountMenuButton extends StatefulWidget {
  final VoidCallback onUploadPressed;
  final VoidCallback onClearConfigPressed;
  final VoidCallback? onPlaybackPressed;
  final VoidCallback? onVibeQueuePressed;
  final bool isServerConnected;

  const _AccountMenuButton({
    required this.onUploadPressed,
    required this.onClearConfigPressed,
    this.onPlaybackPressed,
    this.onVibeQueuePressed,
    this.isServerConnected = false,
  });

  @override
  _AccountMenuButtonState createState() => _AccountMenuButtonState();
}

class _AccountMenuButtonState extends State<_AccountMenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: PopupMenuButton<String>(
        offset: const Offset(0, 56),
        color: const Color(0xFF282828),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF3E3E3E), width: 1),
        ),
        onSelected: (value) {
          if (value == 'vibe') {
            if (widget.onVibeQueuePressed != null) widget.onVibeQueuePressed!();
          } else if (value == 'playback') {
            if (widget.onPlaybackPressed != null) widget.onPlaybackPressed!();
          } else if (value == 'upload') {
            widget.onUploadPressed();
          } else if (value == 'settings') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          } else if (value == 'logout') {
            widget.onClearConfigPressed();
          }
        },
        itemBuilder: (context) => [
          _buildMenuItem('vibe', Icons.tune_rounded, 'Vibe Queue'),
          _buildMenuItem('playback', Icons.graphic_eq_rounded, 'Lyre Playback'),
          _buildMenuItem('upload', Icons.upload_rounded, 'Upload Track'),
          _buildMenuItem('settings', Icons.settings_rounded, 'Settings'),
          _buildMenuItem('logout', Icons.logout_rounded, 'Log Out'),
        ],
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHovered ? const Color(0xFF282828) : const Color(0xFF181818),
              border: Border.all(color: const Color(0xFF3E3E3E), width: 1),
            ),
            child: Icon(Icons.person, color: Provider.of<ThemeService>(context).themeColor, size: 34),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFB3B3B3), size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

class _DraggableTrackItem extends StatefulWidget {
  final int index;
  final Track track;
  final Widget child;
  final Function(int oldIndex, int newIndex) onReorder;
  final String appDataPath;

  const _DraggableTrackItem({
    Key? key,
    required this.index,
    required this.track,
    required this.child,
    required this.onReorder,
    required this.appDataPath,
  }) : super(key: key);

  @override
  State<_DraggableTrackItem> createState() => _DraggableTrackItemState();
}

class _DraggableTrackItemState extends State<_DraggableTrackItem> {
  bool _hoverAbove = true;

  Widget _buildPositionBar(Color themeColor) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: BorderRadius.circular(1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.8),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Provider.of<ThemeService>(context).themeColor;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != widget.index,
      onAcceptWithDetails: (details) {
        final oldIndex = details.data;
        final targetIndex = _hoverAbove ? widget.index : widget.index + 1;
        widget.onReorder(oldIndex, targetIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isTargeted = candidateData.isNotEmpty;

        return MouseRegion(
          onHover: (event) {
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final localOffset = box.globalToLocal(event.position);
              final isTopHalf = localOffset.dy < (box.size.height / 2);
              if (isTopHalf != _hoverAbove) {
                setState(() {
                  _hoverAbove = isTopHalf;
                });
              }
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTargeted && _hoverAbove) _buildPositionBar(themeColor),
              Draggable<int>(
                data: widget.index,
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 340,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xEE1E1E26),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: themeColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TrackCoverImage(
                          trackID: widget.track.trackID,
                          appDataPath: widget.appDataPath,
                          width: 40,
                          height: 40,
                          fallback: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF282828),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.track.title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.track.artist,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                childWhenDragging: Opacity(
                  opacity: 0.35,
                  child: widget.child,
                ),
                child: widget.child,
              ),
              if (isTargeted && !_hoverAbove) _buildPositionBar(themeColor),
            ],
          ),
        );
      },
    );
  }
}
