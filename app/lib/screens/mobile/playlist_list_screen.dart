import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
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
  final VoidCallback onOpenLogin;
  final VoidCallback onSyncPressed;
  final VoidCallback onLogoutPressed;
  final VoidCallback? onPlaybackPressed;

  const PlaylistListScreen({
    Key? key,
    required this.playlists,
    required this.appDataPath,
    required this.mediaHandler,
    required this.serverClient,
    required this.isServerConnected,
    required this.onOpenLogin,
    required this.onSyncPressed,
    required this.onLogoutPressed,
    this.onPlaybackPressed,
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
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.graphic_eq_rounded, color: context.watch<ThemeService>().themeColor, size: 26),
                          const SizedBox(width: 10),
                          Text(
                            'Lyre',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF888888)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2A2A2A),
                          border: Border.all(color: const Color(0xFF555555), width: 1.5),
                        ),
                        child: Icon(Icons.person, color: context.watch<ThemeService>().themeColor, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isServerConnected ? 'Connected User' : 'Guest Account',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isServerConnected ? 'Server Connected' : 'Disconnected (Local)',
                              style: TextStyle(
                                color: isServerConnected ? const Color(0xFF00FF66) : const Color(0xFFFF8888),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Navigation List Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.graphic_eq_rounded,
                    title: 'Lyre Playback',
                    subtitle: 'Equalizer and playback statistics',
                    onTap: () {
                      Navigator.pop(context);
                      if (onPlaybackPressed != null) onPlaybackPressed!();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildDrawerItem(
                    context,
                    icon: Icons.sync_rounded,
                    title: 'Cloud Sync',
                    subtitle: 'Sync playlists & tracks with server',
                    onTap: () {
                      Navigator.pop(context);
                      onSyncPressed();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle: 'Theme customization & app settings',
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
                  if (isServerConnected)
                    _buildDrawerItem(
                      context,
                      icon: Icons.logout_rounded,
                      title: 'Log Out',
                      subtitle: 'Sign out and clear session',
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
                      subtitle: 'Connect to your Lyre account',
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

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF222222), width: 1),
                ),
              ),
              child: const Text(
                'Lyre Mobile',
                style: TextStyle(color: Color(0xFF555555), fontSize: 12),
                textAlign: TextAlign.center,
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
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF888888),
    Color titleColor = const Color(0xFFE8E8E8),
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
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
          style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF444444), size: 18),
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
        title: const Text(
          'Lyre',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () {
                  Scaffold.of(context).openEndDrawer();
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2A2A2A),
                    border: Border.all(color: const Color(0xFF555555), width: 1),
                  ),
                  child: Icon(Icons.person, color: context.watch<ThemeService>().themeColor, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              readOnly: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchScreen(
                      mediaHandler: mediaHandler,
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
          Expanded(
            child: playlists.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        'No playlists available. Sync with server or create playlists on Desktop.',
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
                                allPlaylists: playlists,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F0F),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1A1A1A)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  playlist.title,
                                  style: const TextStyle(fontSize: 16, color: Color(0xFFE8E8E8)),
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Color(0xFF555555)),
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

