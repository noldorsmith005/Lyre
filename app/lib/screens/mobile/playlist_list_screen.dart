import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../models/track.dart';
import '../../services/theme_service.dart';
import '../settings_screen.dart';
import 'playlist_detail_screen.dart';
import 'search_screen.dart';

class PlaylistListScreen extends StatelessWidget {
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
    Key? key,
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
  }) : super(key: key);

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
                      serverClient.registered()
                          ? (serverClient.username != null && serverClient.username.toString().isNotEmpty
                              ? serverClient.username.toString()
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
                      if (onVibeQueuePressed != null) onVibeQueuePressed!();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildDrawerItem(
                    context,
                    icon: Icons.graphic_eq_rounded,
                    title: 'Lyre Playback',
                    onTap: () {
                      Navigator.pop(context);
                      if (onPlaybackPressed != null) onPlaybackPressed!();
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
                  if (serverClient.registered())
                    _buildDrawerItem(
                      context,
                      icon: Icons.logout_rounded,
                      title: 'Log Out',
                      iconColor: const Color(0xFFFF4444),
                      titleColor: const Color(0xFFFF4444),
                      onTap: () {
                        Navigator.pop(context);
                        onLogoutPressed();
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
                        onOpenLogin();
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      endDrawer: _buildMobileDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        actions: [
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
      floatingActionButton: onCreatePlaylist != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 72.0),
              child: FloatingActionButton(
                onPressed: onCreatePlaylist,
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
                            mediaHandler: mediaHandler,
                            serverClient: serverClient,
                            isServerConnected: isServerConnected,
                            onRlsPressed: onRlsPressed,
                            onDownloadTrack: onDownloadTrack,
                            onRemoveDownloadTrack: onRemoveDownloadTrack,
                            appDataPath: appDataPath,
                            allPlaylists: playlists,
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
                    color: isServerConnected
                        ? context.watch<ThemeService>().themeColor
                        : const Color(0xFF888888),
                    size: 28,
                  ),
                  onPressed: onRlsPressed,
                  tooltip: 'Connect to RLS',
                ),
              ],
            ),
          ),
          Expanded(
            child: playlists.isEmpty
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
                : ListView.builder(
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlaylistDetailScreen(
                                playlist: playlist,
                                appDataPath: appDataPath,
                                mediaHandler: mediaHandler,
                                serverClient: serverClient,
                                isServerConnected: isServerConnected,
                                onDownloadTrack: onDownloadTrack,
                                onRemoveDownloadTrack: onRemoveDownloadTrack,
                                allPlaylists: playlists,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F0F),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1A1A1A)),
                          ),

                          child: Row(
                            children: [
                              const Icon(Icons.queue_music, color: Color(0xFF888888), size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  playlist.title,
                                  style: const TextStyle(fontSize: 16, color: Color(0xFFE8E8E8)),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Color(0xFF555555), size: 20),
                                color: const Color(0xFF1E1E1E),
                                onSelected: (value) async {
                                  if (value == 'rename' && onRenamePlaylist != null) {
                                    final controller = TextEditingController(text: playlist.title);
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
                                      onRenamePlaylist!(playlist, newName);
                                    }
                                  } else if (value == 'delete' && onDeletePlaylist != null) {
                                    onDeletePlaylist!(playlist);
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
                            ],
                          ),
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

