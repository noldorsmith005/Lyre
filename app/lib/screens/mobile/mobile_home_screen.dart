import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../services/audio_player_service.dart';
import 'playlist_list_screen.dart';
import 'search_screen.dart';
import '../../widgets/mobile/bottom_player_bar.dart';

class MobileHomeScreen extends StatefulWidget {
  final dynamic mediaHandler;
  final String appDataPath;
  
  const MobileHomeScreen({
    Key? key,
    required this.mediaHandler,
    required this.appDataPath,
  }) : super(key: key);

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _currentIndex = 0;
  List<Playlist> _playlists = [];

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  void _loadPlaylists() async {
    final playlists = await widget.mediaHandler.loadPlaylists();
    setState(() {
      _playlists = playlists;
    });
  }

  void _onCreatePlaylist() async {
    await widget.mediaHandler.createPlaylist();
    _loadPlaylists();
  }

  void _onDeletePlaylist(Playlist playlist) async {
    await widget.mediaHandler.deletePlaylist(playlist.playlistID);
    _loadPlaylists();
  }

  void _onRenamePlaylist(Playlist playlist, String newName) async {
    await widget.mediaHandler.editPlaylistTitle(playlist.playlistID, newName);
    _loadPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              PlaylistListScreen(
                playlists: _playlists,
                onCreatePlaylist: _onCreatePlaylist,
                onDeletePlaylist: _onDeletePlaylist,
                onRenamePlaylist: _onRenamePlaylist,
                appDataPath: widget.appDataPath,
                mediaHandler: widget.mediaHandler,
              ),
              SearchScreen(
                mediaHandler: widget.mediaHandler,
                appDataPath: widget.appDataPath,
                allPlaylists: _playlists,
              ),
            ],
          ),
          
          if (audioService.currentTrack != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0, // Above nav bar, we'll use SafeArea/margin or place it correctly
              child: BottomPlayerBar(appDataPath: widget.appDataPath),
            ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (audioService.currentTrack != null)
            BottomPlayerBar(appDataPath: widget.appDataPath), // Alternative placement for solid layout
          BottomNavigationBar(
            backgroundColor: const Color(0xFF0F0F0F),
            selectedItemColor: const Color(0xFFFF0000),
            unselectedItemColor: const Color(0xFF555555),
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Search',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
