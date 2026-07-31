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
  final VoidCallback? onRlsPressed;
  final Function(Track)? onDownloadTrack;
  final Function(Track)? onRemoveDownloadTrack;
  final String appDataPath;
  final List<Playlist> allPlaylists;

  const SearchScreen({
    Key? key,
    required this.mediaHandler,
    this.serverClient,
    this.isServerConnected = false,
    this.onRlsPressed,
    this.onDownloadTrack,
    this.onRemoveDownloadTrack,
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
  late bool _isServerConnected;

  @override
  void initState() {
    super.initState();
    _isServerConnected = widget.isServerConnected;
  }

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
      final results = (_isServerConnected && widget.serverClient != null)
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
              child: Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.cloud_outlined,
                      color: _isServerConnected
                          ? context.watch<ThemeService>().themeColor
                          : const Color(0xFF888888),
                      size: 28,
                    ),
                    onPressed: () {
                      if (widget.onRlsPressed != null) {
                        widget.onRlsPressed!();
                      }
                      setState(() {
                        _isServerConnected = !_isServerConnected;
                      });
                      if (_searchController.text.trim().isNotEmpty) {
                        _performSearch(_searchController.text);
                      }
                    },
                    tooltip: 'Connect to RLS',
                  ),
                ],
              ),
            ),
            if (_isSearching)
              Expanded(child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(context.watch<ThemeService>().themeColor))))
            else
              Expanded(
                child: ValueListenableBuilder<Set<int>>(
                  valueListenable: widget.serverClient?.downloadingTrackIdsNotifier ?? ValueNotifier<Set<int>>({}),
                  builder: (context, downloadingIds, child) {
                    return ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final track = _searchResults[index];
                        final isDownloading = downloadingIds.contains(track.trackID);
                        return MobileTrackRow(
                          track: track,
                          isPlaying: audioService.currentTrack?.trackID == track.trackID,
                          isDownloading: isDownloading,
                          isServerConnected: _isServerConnected,
                          appDataPath: widget.appDataPath,
                          onTap: () {
                            audioService.playTrackInContext(track, _searchResults);
                          },
                          onDownloadTrack: widget.onDownloadTrack != null ? () async {
                            await widget.onDownloadTrack!(track);
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            }
                          } : null,
                          onRemoveDownloadTrack: widget.onRemoveDownloadTrack != null ? () async {
                            await widget.onRemoveDownloadTrack!(track);
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            }
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
      ),
      bottomNavigationBar: audioService.currentTrack != null
          ? BottomPlayerBar(appDataPath: widget.appDataPath)
          : null,
    );
  }
}


