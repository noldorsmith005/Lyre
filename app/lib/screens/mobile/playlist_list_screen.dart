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

  const PlaylistListScreen({
    Key? key,
    required this.playlists,
    required this.appDataPath,
    required this.mediaHandler,
    required this.serverClient,
    required this.isServerConnected,
    required this.onOpenLogin,
  }) : super(key: key);

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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.cloud_outlined, color: Colors.white),
                onPressed: onOpenLogin,
              ),
              Positioned(
                right: 8,
                top: 10,
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

