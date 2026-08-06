import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/sync_icon_button.dart';
import '../../widgets/track_cover_image.dart';
import '../settings_screen.dart';
import 'playlist_detail_screen.dart';
import 'search_screen.dart';

class PlaylistListScreen extends StatefulWidget {
  final List<Playlist> playlists;
  final String appDataPath;
  final dynamic mediaHandler;
  final dynamic serverClient;
  final bool isServerConnected;
  final VoidCallback? onRlsPressed;
  final Function(Track)? onDownloadTrack;
  final Function(Track)? onRemoveDownloadTrack;
  final VoidCallback onOpenLogin;
  final VoidCallback onLogoutPressed;
  final VoidCallback? onPlaybackPressed;
  final VoidCallback? onVibeQueuePressed;
  final VoidCallback? onCreatePlaylist;
  final Function(Playlist)? onDeletePlaylist;
  final Function(Playlist, String)? onRenamePlaylist;

  const PlaylistListScreen({
    super.key,
    required this.playlists,
    required this.appDataPath,
    required this.mediaHandler,
    required this.serverClient,
    required this.isServerConnected,
    this.onRlsPressed,
    this.onDownloadTrack,
    this.onRemoveDownloadTrack,
    required this.onOpenLogin,
    required this.onLogoutPressed,
    this.onPlaybackPressed,
    this.onVibeQueuePressed,
    this.onCreatePlaylist,
    this.onDeletePlaylist,
    this.onRenamePlaylist,
  });

  @override
  State<PlaylistListScreen> createState() => _PlaylistListScreenState();
}

class _PlaylistListScreenState extends State<PlaylistListScreen> {
  final Map<int, int?> _firstTrackMap = {};

  @override
  void initState() {
    super.initState();
    _loadFirstTracks();
  }

  @override
  void didUpdateWidget(covariant PlaylistListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlists != widget.playlists) {
      _loadFirstTracks();
    }
  }

  Future<void> _loadFirstTracks() async {
    for (final playlist in widget.playlists) {
      try {
        final tracks = await widget.mediaHandler.loadPlaylistTracks(playlist.playlistID);
        if (mounted) {
          setState(() {
            _firstTrackMap[playlist.playlistID] = tracks.isNotEmpty ? tracks.first.trackID : null;
          });
        }
      } catch (_) {}
    }
  }

  Widget _buildMobileDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF121212),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2A2A2A),
                      border: Border.all(color: const Color(0xFF555555), width: 1.5),
                    ),
                    child: Icon(Icons.person, color: context.watch<ThemeService>().themeColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.serverClient.registered()
                          ? (widget.serverClient.username != null && widget.serverClient.username.toString().isNotEmpty
                              ? widget.serverClient.username.toString()
                              : 'Connected User')
                          : 'Guest Account',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Navigation List Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.tune_rounded,
                    title: 'Vibe Queue',
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.onVibeQueuePressed != null) widget.onVibeQueuePressed!();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildDrawerItem(
                    context,
                    icon: Icons.graphic_eq_rounded,
                    title: 'Lyre Playback',
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.onPlaybackPressed != null) widget.onPlaybackPressed!();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(color: Color(0xFF262626), height: 1),
                  ),
                  if (widget.serverClient.registered())
                    _buildDrawerItem(
                      context,
                      icon: Icons.logout_rounded,
                      title: 'Log Out',
                      iconColor: const Color(0xFFFF4444),
                      titleColor: const Color(0xFFFF4444),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onLogoutPressed();
                      },
                    )
                  else
                    _buildDrawerItem(
                      context,
                      icon: Icons.login_rounded,
                      title: 'Log In',
                      iconColor: context.watch<ThemeService>().themeColor,
                      titleColor: context.watch<ThemeService>().themeColor,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onOpenLogin();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF888888),
    Color titleColor = const Color(0xFFE8E8E8),
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          textAlign: TextAlign.left,
          style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);
    final hasPlayBar = audioService.currentTrack != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      endDrawer: _buildMobileDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        actions: [
          SyncIconButton(
            serverClient: widget.serverClient,
            size: 52,
            padding: const EdgeInsets.only(right: 12.0),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () {
                  Scaffold.of(context).openEndDrawer();
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2A2A2A),
                    border: Border.all(color: const Color(0xFF555555), width: 1.5),
                  ),
                  child: Icon(Icons.person, color: context.watch<ThemeService>().themeColor, size: 32),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.onCreatePlaylist != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 72.0),
              child: FloatingActionButton(
                onPressed: widget.onCreatePlaylist,
                backgroundColor: context.watch<ThemeService>().themeColorDark,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchScreen(
                            mediaHandler: widget.mediaHandler,
                            serverClient: widget.serverClient,
                            isServerConnected: widget.isServerConnected,
                            onRlsPressed: widget.onRlsPressed,
                            onDownloadTrack: widget.onDownloadTrack,
                            onRemoveDownloadTrack: widget.onRemoveDownloadTrack,
                            appDataPath: widget.appDataPath,
                            allPlaylists: widget.playlists,
                          ),
                        ),
                      );
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search songs...',
                      hintStyle: const TextStyle(color: Color(0xFF555555)),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.cloud_outlined,
                    color: widget.isServerConnected
                        ? context.watch<ThemeService>().themeColor
                        : const Color(0xFF888888),
                    size: 28,
                  ),
                  onPressed: widget.onRlsPressed,
                  tooltip: 'Connect to RLS',
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.playlists.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'No playlists available. Tap + to create one or sync with server.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF555555), fontSize: 14),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, hasPlayBar ? 15 : 25),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: widget.playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = widget.playlists[index];
                      final firstTrackID = _firstTrackMap[playlist.playlistID];

                      return GestureDetector(
                        onTap: () {
                          widget.mediaHandler.bringPlaylistToFront(playlist.playlistID);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlaylistDetailScreen(
                                playlist: playlist,
                                appDataPath: widget.appDataPath,
                                mediaHandler: widget.mediaHandler,
                                serverClient: widget.serverClient,
                                isServerConnected: widget.isServerConnected,
                                onDownloadTrack: widget.onDownloadTrack,
                                onRemoveDownloadTrack: widget.onRemoveDownloadTrack,
                                allPlaylists: widget.playlists,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF2A2A2A)),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: TrackCoverImage(
                                      trackID: firstTrackID,
                                      appDataPath: widget.appDataPath,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      fallback: Container(
                                        color: const Color(0xFF1E1E1E),
                                        child: const Center(
                                          child: Icon(
                                            Icons.music_note,
                                            size: 48,
                                            color: Color(0xFF555555),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Material(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      shape: const CircleBorder(),
                                      child: PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        color: const Color(0xFF1E1E1E),
                                        onSelected: (value) async {
                                          if (value == 'rename' && widget.onRenamePlaylist != null) {
                                            final controller = TextEditingController(text: playlist.title);
                                            try {
                                              final newName = await showDialog<String>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  backgroundColor: const Color(0xFF1E1E1E),
                                                  title: const Text('Rename Playlist', style: TextStyle(color: Colors.white)),
                                                  content: TextField(
                                                    controller: controller,
                                                    autofocus: true,
                                                    style: const TextStyle(color: Colors.white),
                                                    decoration: const InputDecoration(
                                                      labelText: 'Playlist Name',
                                                      labelStyle: TextStyle(color: Colors.grey),
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, controller.text.trim()),
                                                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (newName != null && newName.isNotEmpty) {
                                                widget.onRenamePlaylist!(playlist, newName);
                                              }
                                            } finally {
                                              controller.dispose();
                                            }
                                          } else if (value == 'delete' && widget.onDeletePlaylist != null) {
                                            widget.onDeletePlaylist!(playlist);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'rename',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, color: Colors.white, size: 18),
                                                SizedBox(width: 10),
                                                Text('Rename', style: TextStyle(color: Colors.white)),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                                SizedBox(width: 10),
                                                Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              playlist.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE8E8E8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


