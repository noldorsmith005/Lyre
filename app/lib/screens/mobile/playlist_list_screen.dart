import 'package:flutter/material.dart';
import '../../models/playlist.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Napster',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 44),
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFF2A2A2A), width: 1),
              ),
              onSelected: (value) {
                if (value == 'playback') {
                  if (onPlaybackPressed != null) onPlaybackPressed!();
                } else if (value == 'sync') {
                  onSyncPressed();
                } else if (value == 'logout') {
                  onLogoutPressed();
                } else if (value == 'login') {
                  onOpenLogin();
                }
              },
              itemBuilder: (context) => [
                _buildMenuItem('playback', Icons.graphic_eq_rounded, 'Napster Playback'),
                _buildMenuItem('sync', Icons.sync_rounded, 'Cloud Sync'),
                if (isServerConnected)
                  _buildMenuItem('logout', Icons.logout_rounded, 'Log Out')
                else
                  _buildMenuItem('login', Icons.login_rounded, 'Log In'),
              ],
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2A2A2A),
                      border: Border.all(color: const Color(0xFF555555), width: 1),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: isServerConnected ? const Color(0xFF00FF66) : const Color(0xFFFF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
                ],
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
                prefixIcon: const Icon(Icons.search, color: Color(0xFF555555)),
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

