import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/track.dart';
import '../../models/playlist.dart';
import '../../services/audio_player_service.dart';
import '../../services/server_client.dart';
import 'playlist_list_screen.dart';
import '../playback_screen.dart';
import '../../services/listening_stats_service.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/vibe_queue_modal.dart';
import '../../services/vibe_queue_service.dart';
import '../../widgets/mobile/bottom_player_bar.dart';
import '../../widgets/playback_notification_modal.dart';
import '../login_screen.dart';



class MobileHomeScreen extends StatefulWidget {
  final dynamic mediaHandler;
  final ServerClient serverClient;
  final String appDataPath;
  
  const MobileHomeScreen({
    super.key,
    required this.mediaHandler,
    required this.serverClient,
    required this.appDataPath,
  });

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> with WidgetsBindingObserver {
  List<Playlist> _playlists = [];
  bool _serverConnection = false;
  bool _isAutoConnecting = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    widget.serverClient.isSyncingNotifier.addListener(_onSyncStatusChanged);
    widget.mediaHandler.onPlaylistChanged = () {
      if (mounted) _loadPlaylists();
    };
    _loadPlaylists();
    _autoConnectServer();
  }

  @override
  void dispose() {
    widget.serverClient.isSyncingNotifier.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    if (!widget.serverClient.isSyncingNotifier.value && mounted) {
      _loadPlaylists();
    }
  }

  Future<void> _checkMonthlyPlaybackNotification() async {
    final stats = await ListeningStatsService.instance.checkAndFetchNewRelease(widget.serverClient);
    if (stats != null && mounted) {
      final allTracks = await widget.mediaHandler.getAllTracks();
      if (!mounted) return;

      PlaybackNotificationModal.show(
        context,
        stats: stats,
        onViewPlayback: () {
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
        },
      );
    }
  }

  Future<void> _autoConnectServer() async {
    if (_isAutoConnecting || widget.serverClient.isSyncing) return;
    if (_lastSyncTime != null && DateTime.now().difference(_lastSyncTime!) < const Duration(seconds: 15)) {
      return;
    }
    _isAutoConnecting = true;
    try {
      if (widget.serverClient.registered()) {
        final canPing = await widget.serverClient.ping();
        if (canPing && mounted) {
          _lastSyncTime = DateTime.now();
          widget.serverClient.performPullSync().then((success) {
            if (mounted) {
              _loadPlaylists();
            }
          });
          _checkMonthlyPlaybackNotification();
        }
      }
    } finally {
      _isAutoConnecting = false;
    }
  }

  void _loadPlaylists() async {
    try {
      final playlists = await widget.mediaHandler.loadPlaylists();
      if (mounted) {
        setState(() {
          _playlists = playlists;
        });
      }
    } catch (e) {
      debugPrint('Error loading mobile playlists: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? const Color(0xFF2A1616) : const Color(0xFF1E1E28),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _onRlsPressed() async {
    if (!_serverConnection && !widget.serverClient.registered()) {
      _openLoginScreen();
    } else {
      setState(() {
        _serverConnection = !_serverConnection;
      });
    }
  }

  Future<bool> _onDownloadTrack(Track track) async {
    final success = await widget.serverClient.downloadTrack(track);
    if (success) {
      track.downloaded = true;
      _loadPlaylists();
      _showSnackBar('Downloaded');
      setState(() {});
      return true;
    } else {
      _showSnackBar('Track download failed or is unavailable on server.', isError: true);
      return false;
    }
  }

  Future<bool> _onRemoveDownloadTrack(Track track) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Remove Download',
      message: 'Are you sure you want to remove "${track.title}" from your local downloads?',
      confirmText: 'Remove',
    );
    if (confirmed == true) {
      final success = await widget.serverClient.removeDownload(track);
      if (!success) {
        _showSnackBar('Failed to remove download on server.', isError: true);
      }
      track.downloaded = false;
      _loadPlaylists();
      _showSnackBar('Removed download for "${track.title}"');
      setState(() {});
      return true;
    }
    return false;
  }

  void _onCreatePlaylist() async {
    await widget.mediaHandler.createPlaylist();
    _loadPlaylists();
  }

  void _onDeletePlaylist(Playlist playlist) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Playlist',
      message: 'Are you sure you want to delete "${playlist.title}"?',
      confirmText: 'Delete',
    );
    if (confirmed == true) {
      await widget.mediaHandler.deletePlaylist(playlist.playlistID);
      _loadPlaylists();
    }
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
      message: 'Are you sure you want to log out? This will clear local data and remote session data.',
      confirmText: 'Log Out',
    );
    if (confirmed == true) {
      final audioService = Provider.of<AudioPlayerService>(context, listen: false);
      await audioService.stopAndClear();
      await widget.serverClient.logout();
      _loadPlaylists();
      setState(() {
        _serverConnection = false;
      });
      if (mounted) {
        _showSnackBar('Logged out and cleared all local data.');
      }
    }
  }

  void _onMobilePlayback() async {
    final allTracks = await widget.mediaHandler.getAllTracks();
    if (!mounted) return;

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

  void _onMobileVibeQueue() {
    VibeQueueModal.show(
      context,
      mediaHandler: widget.mediaHandler,
      onQueueVibe: (tracks, vibe) {
        if (tracks.isEmpty) {
          _showSnackBar('No tracks available for selected vibe.', isError: true);
          return;
        }
        final audioService = Provider.of<AudioPlayerService>(context, listen: false);
        for (final track in tracks) {
          audioService.addToQueue(track);
        }
        if (audioService.currentTrack == null && tracks.isNotEmpty) {
          audioService.play(tracks.first);
        }
        _showSnackBar('Queued ${tracks.length} songs for "${vibe.title}"');
      },
    );
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
        onRlsPressed: _onRlsPressed,
        onDownloadTrack: _onDownloadTrack,
        onRemoveDownloadTrack: _onRemoveDownloadTrack,
        onOpenLogin: _openLoginScreen,
        onLogoutPressed: _onMobileLogout,
        onPlaybackPressed: _onMobilePlayback,
        onVibeQueuePressed: _onMobileVibeQueue,
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



