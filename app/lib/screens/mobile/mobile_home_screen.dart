import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../services/audio_player_service.dart';
import '../../services/server_client.dart';
import 'playlist_list_screen.dart';
import 'search_screen.dart';
import '../../widgets/mobile/bottom_player_bar.dart';
import '../login_screen.dart';

class MobileHomeScreen extends StatefulWidget {
  final dynamic mediaHandler;
  final ServerClient serverClient;
  final String appDataPath;
  
  const MobileHomeScreen({
    Key? key,
    required this.mediaHandler,
    required this.serverClient,
    required this.appDataPath,
  }) : super(key: key);

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _currentIndex = 0;
  List<Playlist> _playlists = [];
  bool _serverConnection = false;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
    _autoConnectServer();
  }

  Future<void> _autoConnectServer() async {
    if (widget.serverClient.registered()) {
      final isValid = await widget.serverClient.validateSession();
      if (isValid && mounted) {
        setState(() {
          _serverConnection = true;
        });
      }
    }
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

  void _openLoginSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          mediaHandler: widget.mediaHandler,
          serverClient: widget.serverClient,
        ),
      ),
    );
  }

  Future<void> _onMobileSync() async {
    if (!_serverConnection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to the server first.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing with server...')),
    );

    try {
      final serverTracks = await widget.serverClient.getUserDownloadedTracks();
      if (serverTracks != null) {
        final serverTrackIds = serverTracks.map((t) => t.trackID).toSet();
        final localTracks = await widget.mediaHandler.getAllTracks();
        final localTrackIds = localTracks.map((t) => t.trackID).toSet();

        for (var st in serverTracks) {
          if (!localTrackIds.contains(st.trackID)) {
            await widget.serverClient.downloadTrack(st);
          }
        }

        for (var lt in localTracks) {
          if (!serverTrackIds.contains(lt.trackID)) {
            await widget.serverClient.removeDownload(lt);
          }
        }
      }

      final serverPlaylists = await widget.serverClient.pullSyncPlaylists();
      if (serverPlaylists != null) {
        await widget.mediaHandler.syncLocalPlaylists(serverPlaylists);
      }

      _loadPlaylists();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync complete!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
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
                serverClient: widget.serverClient,
                isServerConnected: _serverConnection,
                onOpenLogin: _openLoginSheet,
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
              bottom: 0,
              child: BottomPlayerBar(appDataPath: widget.appDataPath),
            ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (audioService.currentTrack != null)
            BottomPlayerBar(appDataPath: widget.appDataPath),
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
