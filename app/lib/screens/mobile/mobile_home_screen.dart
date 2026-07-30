import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../services/audio_player_service.dart';
import '../../services/server_client.dart';
import '../../services/theme_service.dart';
import 'playlist_list_screen.dart';
import '../playback_screen.dart';
import '../../services/listening_stats_service.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/sync_progress_dialog.dart';
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
  List<Playlist> _playlists = [];
  bool _serverConnection = false;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _autoConnectServer();
      }
    });
  }

  Future<void> _autoConnectServer() async {
    if (widget.serverClient.registered()) {
      final canPing = await widget.serverClient.ping();
      if (canPing && mounted) {
        setState(() {
          _serverConnection = true;
        });
        await SyncProgressDialog.show(context, widget.serverClient);
        if (mounted) {
          _loadPlaylists();
        }
      }
    }
  }

  void _loadPlaylists() async {
    final playlists = await widget.mediaHandler.loadPlaylists();
    setState(() {
      _playlists = playlists;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
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

  void _openLoginScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          mediaHandler: widget.mediaHandler,
          serverClient: widget.serverClient,
          onLoginSuccess: () async {
            setState(() {
              _serverConnection = true;
            });
            if (mounted) _loadPlaylists();
          },
        ),
      ),
    );
  }

  void _onMobileLogout() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Log Out',
      message: 'Are you sure you want to log out? This will clear all local playlists, downloaded tracks, server-tracked downloads, and session data.',
      confirmText: 'Log Out',
    );
    if (confirmed == true) {
      final audioService = Provider.of<AudioPlayerService>(context, listen: false);
      await audioService.stopAndClear();
      await widget.serverClient.removeAllTrackedDownloadsServerSide();
      await widget.serverClient.logout();
      _loadPlaylists();
      setState(() {
        _serverConnection = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out and cleared all local data.')),
        );
      }
    }
  }

  void _onMobilePlayback() async {
    final allTracks = await widget.mediaHandler.getAllTracks();
    if (!mounted) return;

    final stats = await ListeningStatsService.instance.fetchOrGetStats(
      widget.serverClient,
      allTracks,
    );

    if (!mounted) return;

    if (stats != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaybackScreen(
            stats: stats,
            allTracks: allTracks,
            serverClient: widget.serverClient,
          ),
        ),
      );
    } else {
      PlaybackScreen.showNoStatsModal(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: PlaylistListScreen(
        playlists: _playlists,
        appDataPath: widget.appDataPath,
        mediaHandler: widget.mediaHandler,
        serverClient: widget.serverClient,
        isServerConnected: _serverConnection,
        onOpenLogin: _openLoginScreen,
        onLogoutPressed: _onMobileLogout,
        onPlaybackPressed: _onMobilePlayback,
        onCreatePlaylist: _onCreatePlaylist,
        onDeletePlaylist: _onDeletePlaylist,
        onRenamePlaylist: _onRenamePlaylist,
      ),
      bottomNavigationBar: audioService.currentTrack != null
          ? BottomPlayerBar(appDataPath: widget.appDataPath)
          : null,
    );
  }
}


