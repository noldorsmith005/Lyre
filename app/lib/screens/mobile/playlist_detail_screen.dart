import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/mobile/mobile_track_row.dart';
import '../../widgets/mobile/mobile_playlist_actions_sheet.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  final String appDataPath;
  final dynamic mediaHandler; // Inject MediaHandler for playlist operations
  final List<Playlist> allPlaylists;

  const PlaylistDetailScreen({
    Key? key,
    required this.playlist,
    required this.appDataPath,
    required this.mediaHandler,
    required this.allPlaylists,
  }) : super(key: key);

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Playlist _playlist;
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final tracks = await widget.mediaHandler.loadPlaylistTracks(_playlist.playlistID);
    setState(() {
      _tracks = tracks;
      _isLoading = false;
    });
  }

  String _formatDuration(int totalSeconds) {
    final d = Duration(seconds: totalSeconds);
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }



  void _showTrackActions(BuildContext context, Track track) {
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MobilePlaylistActionsSheet(
          track: track,
          allPlaylists: widget.allPlaylists,
          onAddToQueue: () {
            audioService.addToQueue(track);
          },
          onAddToPlaylist: (targetPlaylist) {
            // targetPlaylist.tracks.add(track);
            // widget.mediaHandler.savePlaylist(targetPlaylist);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);
    int totalDuration = 0;
    for (var track in _tracks) {
      final parts = track.duration.split(':');
      if (parts.length == 2) {
        totalDuration += int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_playlist.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(audioService.shuffle ? Icons.shuffle_on : Icons.shuffle, color: audioService.shuffle ? const Color(0xFFFF0000) : Colors.white),
            onPressed: () {
              audioService.setShuffle();
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0000)))
        : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              '${_tracks.length} tracks | Duration: ${_formatDuration(totalDuration)}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                final track = _tracks[index];
                return MobileTrackRow(
                  key: ValueKey(track.trackID),
                  track: track,
                  isPlaying: audioService.currentTrack?.trackID == track.trackID,
                  appDataPath: widget.appDataPath,
                  onTap: () {
                    // Play this track and add the rest to queue
                    final remaining = _tracks.sublist(index);
                    if (remaining.isNotEmpty) {
                      audioService.clearPlaylistQueue();
                      audioService.play(remaining.first);
                      for (int i = 1; i < remaining.length; i++) {
                        audioService.addToPlaylistQueue(remaining[i]);
                      }
                    }
                  },
                  onLongPress: () => _showTrackActions(context, track),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
