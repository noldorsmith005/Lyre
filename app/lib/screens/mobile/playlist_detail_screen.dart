import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/mobile/mobile_track_row.dart';
import '../../widgets/mobile/bottom_player_bar.dart';
import '../../widgets/mobile/mobile_playlist_actions_sheet.dart';



class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  final String appDataPath;
  final dynamic mediaHandler;
  final dynamic serverClient;
  final bool isServerConnected;
  final Function(Track)? onDownloadTrack;
  final Function(Track)? onRemoveDownloadTrack;
  final List<Playlist> allPlaylists;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.appDataPath,
    required this.mediaHandler,
    this.serverClient,
    this.isServerConnected = false,
    this.onDownloadTrack,
    this.onRemoveDownloadTrack,
    required this.allPlaylists,
  });

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
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _isLoading = false;
    });
  }

  String _formatDuration(int totalSeconds) {
    final d = Duration(seconds: totalSeconds);
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);
    final hasPlayBar = audioService.currentTrack != null;
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: context.watch<ThemeService>().themeColor))
        : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _playlist.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tracks.length} tracks',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Duration: ${_formatDuration(totalDuration)}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  iconSize: 28,
                  icon: const Icon(Icons.shuffle),
                  color: audioService.shuffle ? context.watch<ThemeService>().themeColor : Colors.white,
                  onPressed: () {
                    audioService.setShuffle();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Set<int>>(
              valueListenable: widget.serverClient?.downloadingTrackIdsNotifier ?? ValueNotifier<Set<int>>({}),
              builder: (context, downloadingIds, child) {
                return ReorderableListView.builder(
                  padding: EdgeInsets.only(bottom: hasPlayBar ? 15 : 96),
                  itemCount: _tracks.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (oldIndex < 0 || oldIndex >= _tracks.length) return;
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    if (oldIndex == newIndex) return;

                    setState(() {
                      final item = _tracks.removeAt(oldIndex);
                      _tracks.insert(newIndex, item);
                    });

                    final trackIds = _tracks.map((t) => t.trackID).toList();
                    await widget.mediaHandler.reorderPlaylistTracks(_playlist.playlistID, trackIds);
                    if (widget.isServerConnected && widget.serverClient != null) {
                      await widget.serverClient.pushLocalPlaylists();
                    }
                  },
                  itemBuilder: (context, index) {
                    final track = _tracks[index];
                    final isDownloading = downloadingIds.contains(track.trackID);
                    return MobileTrackRow(
                      key: ValueKey('${track.trackID}_$index'),
                      track: track,
                      isPlaying: audioService.currentTrack?.trackID == track.trackID,
                      isDownloading: isDownloading,
                      isServerConnected: widget.isServerConnected,
                      appDataPath: widget.appDataPath,
                      onTap: () {
                        audioService.playTrackInContext(track, _tracks);
                      },
                      onDownloadTrack: widget.onDownloadTrack != null ? () async {
                        await widget.onDownloadTrack!(track);
                        await _loadTracks();
                      } : null,
                      onRemoveDownloadTrack: widget.onRemoveDownloadTrack != null ? () async {
                        await widget.onRemoveDownloadTrack!(track);
                        await _loadTracks();
                      } : null,
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => MobilePlaylistActionsSheet(
                            track: track,
                            allPlaylists: widget.allPlaylists,
                            mediaHandler: widget.mediaHandler,
                          ),
                        );
                      },
                      onQueue: () {
                        audioService.addToQueue(track);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: audioService.currentTrack != null
          ? BottomPlayerBar(appDataPath: widget.appDataPath)
          : null,
    );
  }
}


