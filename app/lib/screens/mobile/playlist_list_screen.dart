import 'package:flutter/material.dart';
import '../../models/playlist.dart';
import 'playlist_detail_screen.dart';

class PlaylistListScreen extends StatelessWidget {
  final List<Playlist> playlists;
  final VoidCallback onCreatePlaylist;
  final Function(Playlist) onDeletePlaylist;
  final Function(Playlist, String) onRenamePlaylist;
  final String appDataPath;
  final dynamic mediaHandler;
  final dynamic serverClient;
  final bool isServerConnected;
  final VoidCallback onOpenLogin;

  const PlaylistListScreen({
    Key? key,
    required this.playlists,
    required this.onCreatePlaylist,
    required this.onDeletePlaylist,
    required this.onRenamePlaylist,
    required this.appDataPath,
    required this.mediaHandler,
    required this.serverClient,
    required this.isServerConnected,
    required this.onOpenLogin,
  }) : super(key: key);

  void _showPlaylistOptions(BuildContext context, Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF888888)),
                title: const Text('Rename Playlist', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, playlist);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Color(0xFFFF4444)),
                title: const Text('Delete Playlist', style: TextStyle(color: Color(0xFFFF4444))),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(context, playlist);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, Playlist playlist) {
    final controller = TextEditingController(text: playlist.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2B2B2B),
          title: const Text('Rename Playlist', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF888888))),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty && newName != playlist.title) {
                  onRenamePlaylist(playlist, newName);
                }
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Color(0xFFFF0000))),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2B2B2B),
          title: const Text('Delete Playlist', style: TextStyle(color: Colors.white)),
          content: Text('Are you sure you want to delete "${playlist.title}"?', style: const TextStyle(color: Color(0xFFE8E8E8))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF888888))),
            ),
            TextButton(
              onPressed: () {
                onDeletePlaylist(playlist);
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Color(0xFFFF4444))),
            ),
          ],
        );
      },
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
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: onCreatePlaylist,
          ),
        ],
      ),
      body: ListView.builder(
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
            onLongPress: () => _showPlaylistOptions(context, playlist),
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
    );
  }
}
