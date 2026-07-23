import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/track.dart';
import '../../models/playlist.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/mobile/mobile_track_row.dart';
import '../../widgets/mobile/mobile_playlist_actions_sheet.dart';

class SearchScreen extends StatefulWidget {
  final dynamic mediaHandler;
  final String appDataPath;
  final List<Playlist> allPlaylists;

  const SearchScreen({
    Key? key,
    required this.mediaHandler,
    required this.appDataPath,
    required this.allPlaylists,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _searchResults = [];
  bool _isSearching = false;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
    });

    try {
      // Assuming mediaHandler has searchTracks for local lookup
      final results = await widget.mediaHandler.searchTracks(query); 
      setState(() {
        _searchResults = results.cast<Track>();
      });
    } catch (e) {
      // Handle error gracefully
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
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
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF555555)),
                ),
                onSubmitted: _performSearch,
                textInputAction: TextInputAction.search,
              ),
            ),
            if (_isSearching)
              const Expanded(child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)))))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final track = _searchResults[index];
                    return MobileTrackRow(
                      track: track,
                      isPlaying: audioService.currentTrack?.trackID == track.trackID,
                      appDataPath: widget.appDataPath,
                      onTap: () {
                        audioService.play(track);
                      },
                      onLongPress: () => _showTrackActions(context, track),
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
