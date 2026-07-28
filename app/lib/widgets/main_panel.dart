import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../screens/settings_screen.dart';
import '../services/theme_service.dart';
import '../services/audio_player_service.dart';
import '../utils/platform_utils.dart';
import 'track_card.dart';

class MainPanel extends StatefulWidget {
  final Playlist? currentPlaylist;
  final List<Track> tracks;
  final Function(String) onSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onRlsPressed;
  final VoidCallback onUploadPressed;
  final VoidCallback onClearConfigPressed;
  final VoidCallback onSyncPressed;
  final VoidCallback? onPlaybackPressed;
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

  const MainPanel({
    Key? key,
    this.currentPlaylist,
    required this.tracks,
    required this.onSearch,
    required this.onClearSearch,
    required this.onRlsPressed,
    required this.onUploadPressed,
    required this.onClearConfigPressed,
    required this.onSyncPressed,
    this.onPlaybackPressed,
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
    this.isServerConnected = false,
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

  void _showEditPlaylistDialog() {
    if (widget.currentPlaylist == null) return;
    
    final TextEditingController nameController = TextEditingController(text: widget.currentPlaylist!.title);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF282828),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Playlist',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDeletePlaylist();
                      },
                      child: const Text('Delete'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Provider.of<ThemeService>(context, listen: false).themeColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(bottom: BorderSide(color: Color(0xFF282828), width: 1)),
      ),
      child: Row(
        children: [
          // Spotify-style Pill Search Bar
          _SpotifySearchBar(
            controller: _searchController,
            onSearch: widget.onSearch,
            onClearSearch: widget.onClearSearch,
          ),
          if (showServerFeatures) ...[
            const SizedBox(width: 16),
            Tooltip(
              message: 'Connect to RLS',
              child: _HoverIconButton(
                icon: widget.isServerConnected ? Icons.cloud : Icons.cloud_outlined,
                size: 26,
                color: widget.isServerConnected
                    ? Provider.of<ThemeService>(context).themeColor
                    : const Color(0xFFB3B3B3),
                onTap: widget.onRlsPressed,
              ),
            ),
          ],
          const Spacer(),
          
          if (showServerFeatures) ...[
            _AccountMenuButton(
              onUploadPressed: widget.onUploadPressed,
              onClearConfigPressed: widget.onClearConfigPressed,
              onSyncPressed: widget.onSyncPressed,
              onPlaybackPressed: widget.onPlaybackPressed,
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
        color: Color(0xFF121212),
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
                  size: 28,
                  color: isShuffled ? themeColor : const Color(0xFFB3B3B3),
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
      color: const Color(0xFF121212),
      child: Column(
        children: [
          _buildTopBar(),
          _buildHeaderRow(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              itemCount: widget.tracks.length,
              itemBuilder: (context, index) {
                final track = widget.tracks[index];
                final isPlaying = widget.playingTrack?.trackID == track.trackID;
                return TrackCard(
                  track: track,
                  isDownloaded: track.downloaded,
                  isPlaying: isPlaying,
                  onPlay: () => widget.onPlayTrack(track),
                  onDownload: widget.onDownloadTrack != null ? () => widget.onDownloadTrack!(track) : null,
                  onRemoveDownload: widget.onRemoveDownloadTrack != null ? () => widget.onRemoveDownloadTrack!(track) : null,
                  onQueue: () => widget.onQueueTrack(track),
                  availablePlaylists: widget.availablePlaylists,
                  onTogglePlaylist: widget.onTogglePlaylist,
                  isTrackInPlaylist: widget.isTrackInPlaylist,
                  appDataPath: Provider.of<AudioPlayerService>(context, listen: false).appDataPath ?? '',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotifySearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final VoidCallback onClearSearch;

  const _SpotifySearchBar({
    required this.controller,
    required this.onSearch,
    required this.onClearSearch,
  });

  @override
  _SpotifySearchBarState createState() => _SpotifySearchBarState();
}

class _SpotifySearchBarState extends State<_SpotifySearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Provider.of<ThemeService>(context).themeColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 360,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: _isFocused ? themeColor : const Color(0xFF282828),
          width: _isFocused ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: _isFocused ? themeColor : const Color(0xFFB3B3B3),
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onSearch,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search songs, artists...',
                hintStyle: TextStyle(color: Color(0xFF757575), fontSize: 14),
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
            color: widget.color ?? (_isHovered ? Colors.white : const Color(0xFFB3B3B3)),
          ),
        ),
      ),
    );
  }
}

class _AccountMenuButton extends StatefulWidget {
  final VoidCallback onUploadPressed;
  final VoidCallback onClearConfigPressed;
  final VoidCallback onSyncPressed;
  final VoidCallback? onPlaybackPressed;
  final bool isServerConnected;

  const _AccountMenuButton({
    required this.onUploadPressed,
    required this.onClearConfigPressed,
    required this.onSyncPressed,
    this.onPlaybackPressed,
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
        offset: const Offset(0, 44),
        color: const Color(0xFF282828),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF3E3E3E), width: 1),
        ),
        onSelected: (value) {
          if (value == 'playback') {
            if (widget.onPlaybackPressed != null) widget.onPlaybackPressed!();
          } else if (value == 'sync') {
            widget.onSyncPressed();
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
          _buildMenuItem('playback', Icons.graphic_eq_rounded, 'Napster Playback'),
          _buildMenuItem('sync', Icons.sync_rounded, 'Cloud Sync'),
          _buildMenuItem('upload', Icons.upload_rounded, 'Upload Track'),
          _buildMenuItem('settings', Icons.settings_rounded, 'Settings'),
          _buildMenuItem('logout', Icons.logout_rounded, 'Log Out'),
        ],
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHovered ? const Color(0xFF282828) : const Color(0xFF181818),
              border: Border.all(color: const Color(0xFF3E3E3E), width: 1),
            ),
            child: Icon(Icons.person, color: Provider.of<ThemeService>(context).themeColor, size: 20),
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
