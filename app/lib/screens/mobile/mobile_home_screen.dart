import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/playlist.dart';
import '../../services/audio_player_service.dart';
import '../../services/server_client.dart';
import '../../services/theme_service.dart';
import 'playlist_list_screen.dart';
import '../playback_screen.dart';
import '../../services/listening_stats_service.dart';
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
    _autoConnectServer();
  }

  Future<void> _autoConnectServer() async {
    bool isConnected = false;
    if (widget.serverClient.registered()) {
      final isValid = await widget.serverClient.validateSession();
      if (isValid && mounted) {
        setState(() {
          _serverConnection = true;
        });
        isConnected = true;
        // Background history sync to server
        ListeningStatsService.instance.syncLocalHistoryToServer(widget.serverClient);
      }
    }
    if (!isConnected && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_serverConnection) {
          _openLoginScreen();
        }
      });
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

  void _openLoginScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          mediaHandler: widget.mediaHandler,
          serverClient: widget.serverClient,
          onLoginSuccess: () {
            setState(() {
              _serverConnection = true;
            });
            _onMobileSync();
          },
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

    final statusNotifier = ValueNotifier<_SyncStatus>(_SyncStatus(0.1, 'Fetching server metadata...'));

    final themeColor = Provider.of<ThemeService>(context, listen: false).themeColor;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<_SyncStatus>(
        valueListenable: statusNotifier,
        builder: (context, status, child) {
          return AlertDialog(
            backgroundColor: const Color(0xFF161616),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Icon(Icons.cloud_sync, color: themeColor),
                const SizedBox(width: 10),
                const Text('Cloud Sync', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.message, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: status.progress,
                    color: themeColor,
                    backgroundColor: const Color(0xFF333333),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(status.progress * 100).toInt()}%',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final serverTracks = await widget.serverClient.getUserDownloadedTracks();
      statusNotifier.value = _SyncStatus(0.3, 'Syncing local track downloads...');
      if (serverTracks != null) {
        final serverTrackIds = serverTracks.map((t) => t.trackID).toSet();
        final localTracks = await widget.mediaHandler.getAllTracks();
        final localTrackIds = localTracks.map((t) => t.trackID).toSet();

        num totalTracks = serverTracks.length + localTracks.length;
        int count = 0;

        for (var st in serverTracks) {
          count++;
          double p = 0.3 + (0.4 * count / (totalTracks == 0 ? 1 : totalTracks));
          statusNotifier.value = _SyncStatus(p, 'Downloading "${st.title}"...');
          if (!localTrackIds.contains(st.trackID)) {
            await widget.serverClient.downloadTrack(st, updateServerTracking: false);
          }
        }

        for (var lt in localTracks) {
          count++;
          double p = 0.3 + (0.4 * count / (totalTracks == 0 ? 1 : totalTracks));
          statusNotifier.value = _SyncStatus(p, 'Updating track state...');
          if (!serverTrackIds.contains(lt.trackID)) {
            await widget.serverClient.removeDownload(lt, updateServerTracking: false);
          }
        }
      }

      statusNotifier.value = _SyncStatus(0.75, 'Pulling playlists from server...');
      final serverPlaylists = await widget.serverClient.pullSyncPlaylists();
      if (serverPlaylists != null) {
        statusNotifier.value = _SyncStatus(0.9, 'Updating local playlists...');
        await widget.mediaHandler.syncLocalPlaylists(serverPlaylists);
      }

      _loadPlaylists();

      statusNotifier.value = _SyncStatus(1.0, 'Sync Complete!');
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync complete!')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  void _onMobileLogout() async {
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    await audioService.stopAndClear();
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

  void _onMobilePlayback() async {
    final allTracks = await widget.mediaHandler.getAllTracks();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaybackScreen(
            allTracks: allTracks,
            serverClient: widget.serverClient,
          ),
        ),
      );
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
        onSyncPressed: _onMobileSync,
        onLogoutPressed: _onMobileLogout,
        onPlaybackPressed: _onMobilePlayback,
      ),
      bottomNavigationBar: audioService.currentTrack != null
          ? BottomPlayerBar(appDataPath: widget.appDataPath)
          : null,
    );
  }
}

class _SyncStatus {
  final double progress;
  final String message;
  _SyncStatus(this.progress, this.message);
}


