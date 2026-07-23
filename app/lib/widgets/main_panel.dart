import 'package:flutter/material.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import 'package:provider/provider.dart';
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
  final VoidCallback onShufflePressed;
  final Function(String) onEditPlaylistName;
  final VoidCallback onDeletePlaylist;
  final Track? playingTrack;
  final Function(Track) onPlayTrack;
  final Function(Track)? onDownloadTrack;
  final Function(Track) onQueueTrack;
  final List<Playlist> availablePlaylists;
  final Function(Playlist, Track) onTogglePlaylist;
  final bool Function(Playlist, Track) isTrackInPlaylist;

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
    required this.onShufflePressed,
    required this.onEditPlaylistName,
    required this.onDeletePlaylist,
    this.playingTrack,
    required this.onPlayTrack,
    this.onDownloadTrack,
    required this.onQueueTrack,
    required this.availablePlaylists,
    required this.onTogglePlaylist,
    required this.isTrackInPlaylist,
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
          backgroundColor: const Color(0xFF2B2B2B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          child: Container(
            width: 300,
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
                    fillColor: const Color(0xFF3C3F41),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
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
                        backgroundColor: const Color(0xFFFF0000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDeletePlaylist();
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF555555),
                      ),
                      onPressed: () {
                        widget.onEditPlaylistName(nameController.text);
                        Navigator.pop(context);
                      },
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
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
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
      ),
      child: Row(
        children: [
          // Search Field
          Container(
            width: 360,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(500),
              border: Border.all(color: Colors.white, width: 0.8),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 48, right: 12),
                  child: Icon(Icons.search, color: Colors.white, size: 18),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: widget.onSearch,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search songs...',
                      hintStyle: TextStyle(color: Color(0xFFB3B3B3)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        widget.onClearSearch();
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(Icons.close, color: Color(0xFF555555), size: 18),
                      ),
                    ),
                  ),
                const SizedBox(width: 42),
              ],
            ),
          ),
          const Spacer(),
          
          if (showServerFeatures) ...[
            _HoverIconButton(
              iconPath: 'assets/library_selected.png',
              size: 30,
              onTap: widget.onRlsPressed,
            ),
            const SizedBox(width: 16),
            _AccountMenuButton(
              onUploadPressed: widget.onUploadPressed,
              onClearConfigPressed: widget.onClearConfigPressed,
              onSyncPressed: widget.onSyncPressed,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 32, 20, 32),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
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
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.currentPlaylist != null) ...[
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: _showEditPlaylistDialog,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF555555),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: const Text('Edit Playlist'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.tracks.length} tracks',
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const Spacer(),
          _HoverIconButton(
            iconPath: 'assets/shuffle.png',
            size: 32,
            onTap: widget.onShufflePressed,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: Colors.black,
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
                  // For the sake of this UI widget, assume tracks in the list are downloaded if not mobile,
                  // or handled by parent. We'll pass a mock isDownloaded = true for now, 
                  // but ideally it comes from the model or parent.
                  return TrackCard(
                    track: track,
                    isDownloaded: true, // Placeholder for download state logic
                    isPlaying: isPlaying,
                    onPlay: () => widget.onPlayTrack(track),
                    onDownload: widget.onDownloadTrack != null ? () => widget.onDownloadTrack!(track) : null,
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
      ),
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  final String iconPath;
  final double size;
  final VoidCallback onTap;

  const _HoverIconButton({
    required this.iconPath,
    required this.size,
    required this.onTap,
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
        child: Opacity(
          opacity: _isHovered ? 0.7 : 1.0,
          child: Image.asset(
            widget.iconPath,
            width: widget.size,
            height: widget.size,
            color: Colors.white,
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

  const _AccountMenuButton({
    required this.onUploadPressed,
    required this.onClearConfigPressed,
    required this.onSyncPressed,
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
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
        onSelected: (value) {
          if (value == 'sync') {
            widget.onSyncPressed();
          } else if (value == 'upload') {
            widget.onUploadPressed();
          } else if (value == 'clear_config') {
            widget.onClearConfigPressed();
          }
        },
        itemBuilder: (context) => [
          _buildMenuItem('sync', Icons.sync_rounded, 'Sync Playlists'),
          _buildMenuItem('upload', Icons.upload_rounded, 'Upload Track'),
          _buildMenuItem('clear_config', Icons.delete_outline, 'Clear Server Config'),
        ],
        child: Opacity(
          opacity: _isHovered ? 0.7 : 1.0,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2A2A),
              border: Border.all(color: const Color(0xFF555555), width: 1),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
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
          Icon(icon, color: const Color(0xFF888888), size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Color(0xFFE8E8E8), fontSize: 14)),
        ],
      ),
    );
  }
}
