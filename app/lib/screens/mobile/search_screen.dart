import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/track.dart';
import '../../models/playlist.dart';
import '../../services/audio_player_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/mobile/mobile_track_row.dart';
import '../../widgets/mobile/bottom_player_bar.dart';
import '../../widgets/mobile/mobile_playlist_actions_sheet.dart';

class SearchScreen extends StatefulWidget {
  final dynamic mediaHandler;
  final dynamic serverClient;
  final bool isServerConnected;
  final String appDataPath;
  final List<Playlist> allPlaylists;

  const SearchScreen({
    Key? key,
    required this.mediaHandler,
    this.serverClient,
    this.isServerConnected = false,
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      final results = (widget.isServerConnected && widget.serverClient != null)
          ? await widget.serverClient.searchTracks(query)
          : await widget.mediaHandler.searchTracks(query); 
      setState(() {
        _searchResults = results.cast<Track>();
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Search', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF555555)),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                ),
                onSubmitted: _performSearch,
                onChanged: _performSearch,
                textInputAction: TextInputAction.search,
              ),
            ),
            if (_isSearching)
              Expanded(child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(context.watch<ThemeService>().themeColor))))
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
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => MobilePlaylistActionsSheet(
                            track: track,
                            allPlaylists: widget.allPlaylists,
                            onAddToPlaylist: (playlist) async {
                              await widget.mediaHandler.addToPlaylist(playlist.playlistID, track.trackID);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Added ${track.title} to ${playlist.title}')),
                                );
                              }
                            },
                          ),
                        );
                      },
                      onQueue: () {
                        audioService.addToQueue(track);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: audioService.currentTrack != null
          ? BottomPlayerBar(appDataPath: widget.appDataPath)
          : null,
    );
  }
}

