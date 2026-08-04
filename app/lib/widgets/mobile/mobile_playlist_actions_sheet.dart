import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/track.dart';
import '../../models/playlist.dart';
import '../../services/theme_service.dart';



class MobilePlaylistActionsSheet extends StatefulWidget {
  final Track track;
  final List<Playlist> allPlaylists;
  final dynamic mediaHandler;

  const MobilePlaylistActionsSheet({
    super.key,
    required this.track,
    required this.allPlaylists,
    required this.mediaHandler,
  });

  @override
  State<MobilePlaylistActionsSheet> createState() => _MobilePlaylistActionsSheetState();
}

class _MobilePlaylistActionsSheetState extends State<MobilePlaylistActionsSheet> {
  final Map<int, bool> _inPlaylistMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkMemberships();
  }

  Future<void> _checkMemberships() async {
    for (final playlist in widget.allPlaylists) {
      final inPlaylist = await widget.mediaHandler.isInPlaylist(playlist.playlistID, widget.track.trackID);
      _inPlaylistMap[playlist.playlistID] = inPlaylist;
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlaylist(Playlist playlist) async {
    final currentlyIn = _inPlaylistMap[playlist.playlistID] ?? false;
    if (currentlyIn) {
      await widget.mediaHandler.removeFromPlaylist(playlist.playlistID, widget.track.trackID);
      _inPlaylistMap[playlist.playlistID] = false;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed from ${playlist.title}', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1E1E28),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } else {
      await widget.mediaHandler.addToPlaylist(playlist.playlistID, widget.track.trackID);
      _inPlaylistMap[playlist.playlistID] = true;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to ${playlist.title}', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1E1E28),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final themeColor = context.watch<ThemeService>().themeColor;

    return Container(
      height: screenHeight * 0.5,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar & title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E3E3E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    widget.track.title,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.track.artist,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFB3B3B3),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF282828), height: 1),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: themeColor))
                  : widget.allPlaylists.isEmpty
                      ? const Center(
                          child: Text(
                            'No playlists available',
                            style: TextStyle(color: Color(0xFF666666), fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          itemCount: widget.allPlaylists.length,
                          itemBuilder: (context, index) {
                            final playlist = widget.allPlaylists[index];
                            final inPlaylist = _inPlaylistMap[playlist.playlistID] ?? false;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                              title: Text(
                                playlist.title,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                              ),
                              trailing: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: inPlaylist ? themeColor : Colors.transparent,
                                  border: Border.all(
                                    color: inPlaylist ? themeColor : const Color(0xFF555555),
                                    width: 2.0,
                                  ),
                                ),
                              ),
                              onTap: () => _togglePlaylist(playlist),
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
