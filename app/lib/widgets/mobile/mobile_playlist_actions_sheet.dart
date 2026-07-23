import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../models/playlist.dart';

class MobilePlaylistActionsSheet extends StatelessWidget {
  final Track track;
  final List<Playlist> allPlaylists;
  final VoidCallback onAddToQueue;
  final Function(Playlist) onAddToPlaylist;

  const MobilePlaylistActionsSheet({
    Key? key,
    required this.track,
    required this.allPlaylists,
    required this.onAddToQueue,
    required this.onAddToPlaylist,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF555555),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    track.title,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            ListTile(
              leading: const Icon(Icons.queue_music, color: Color(0xFF888888)),
              title: const Text('Add to Queue', style: TextStyle(fontSize: 16, color: Colors.white)),
              onTap: () {
                onAddToQueue();
                Navigator.pop(context);
              },
            ),
            ExpansionTile(
              leading: const Icon(Icons.playlist_add, color: Color(0xFF888888)),
              title: const Text('Add to Playlist', style: TextStyle(fontSize: 16, color: Colors.white)),
              iconColor: const Color(0xFF888888),
              collapsedIconColor: const Color(0xFF888888),
              children: allPlaylists.map((playlist) {
                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 72, right: 16),
                  title: Text(playlist.title, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.circle_outlined, color: Color(0xFF555555), size: 12),
                  onTap: () {
                    onAddToPlaylist(playlist);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
