import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/media_handler.dart';
import '../services/server_client.dart';
import '../services/audio_player_service.dart';
import '../services/theme_service.dart';
import '../utils/layout_constants.dart';
import '../widgets/sidebar.dart';
import '../widgets/main_panel.dart';
import '../widgets/media_panel.dart';
import 'login_screen.dart';
import 'playback_screen.dart';
import 'settings_screen.dart';
import '../widgets/upload_modal.dart';
import '../widgets/confirmation_dialog.dart';
import 'register_screen.dart';

import '../services/listening_stats_service.dart';

class HomeScreen extends StatefulWidget {
  final MediaHandler mediaHandler;
  final ServerClient serverClient;

  const HomeScreen({
    Key? key,
    required this.mediaHandler,
    required this.serverClient,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Playlist> _playlists = [];
  List<Track> _tracks = [];
  Playlist? _currentPlaylist;
  bool _serverConnection = false;
  Map<int, List<int>> _playlistTracksMap = {};

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
    _autoConnectServer();
  }

  Future<void> _autoConnectServer() async {
    if (mounted) {
      setState(() {
        _serverConnection = false;
      });
    }
  }

  void _showLoginScreen() {
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
          },
        ),
      ),
    );
  }

  Future<void> _loadPlaylists() async {
    final playlists = await widget.mediaHandler.loadPlaylists();
    final Map<int, List<int>> map = {};
    for (final pl in playlists) {
      final tracks = await widget.mediaHandler.loadPlaylistTracks(pl.playlistID);
      map[pl.playlistID] = tracks.map((t) => t.trackID).toList();
    }
    setState(() {
      _playlists = playlists;
      _playlistTracksMap = map;
    });
  }

  Future<void> _loadPlaylistTracks(Playlist playlist) async {
    final tracks = await widget.mediaHandler.loadPlaylistTracks(playlist.playlistID);
    setState(() {
      _currentPlaylist = playlist;
      _tracks = tracks;
    });
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) return;
    List<Track> results;
    if (_serverConnection) {
      try {
        results = await widget.serverClient.searchTracks(query);
      } catch (e) {
        results = await widget.mediaHandler.searchTracks(query);
      }
    } else {
      results = await widget.mediaHandler.searchTracks(query);
    }
    setState(() {
      _currentPlaylist = null;
      _tracks = results;
    });
  }

  void _onRlsPressed() async {
    if (!_serverConnection && !widget.serverClient.registered()) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            mediaHandler: widget.mediaHandler,
            serverClient: widget.serverClient,
            onLoginSuccess: () {
              setState(() {
                _serverConnection = true;
              });
            },
          ),
        ),
      );
    } else {
      final canPing = await widget.serverClient.ping();
      if (canPing) {
        setState(() {
          _serverConnection = !_serverConnection;
        });
      } else {
        _showAlert('Server Error', 'Server Offline');
      }
    }
  }

  void _onUploadPressed() {
    if (_serverConnection) {
      UploadModal.show(
        context,
        onUpload: (title, artist, mediaPath, coverPath) async {
          try {
            final newTrack = Track(
              trackID: 0,
              title: title,
              artist: artist,
              duration: '',
            );
            await widget.serverClient.uploadTrack(newTrack, mediaPath, coverPath);
            if (mounted) Navigator.of(context).pop();
          } catch (e) {
            _showAlert('Upload Error', e.toString());
          }
        },
      );
    } else {
      _showAlert('Server Error', 'Connect to server');
    }
  }

  void _onClearConfigPressed() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Log Out',
      message: 'Are you sure you want to log out? This will clear all local playlists, downloaded tracks, server-tracked downloads, and session data.',
    );
    if (confirmed == true) {
      final audioService = Provider.of<AudioPlayerService>(context, listen: false);
      await audioService.stopAndClear();
      await widget.serverClient.removeAllTrackedDownloadsServerSide();
      await widget.serverClient.logout();
      await _loadPlaylists();
      setState(() {
        _currentPlaylist = null;
        _tracks = [];
        _serverConnection = false;
      });
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              mediaHandler: widget.mediaHandler,
              serverClient: widget.serverClient,
              onLoginSuccess: () {
                setState(() {
                  _serverConnection = true;
                });
              },
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  Future<void> _onSyncPressed() async {
    if (!_serverConnection) {
      _showAlert('Sync Error', 'Please connect to the server first.');
      return;
    }

    final statusNotifier = ValueNotifier<_SyncStatus>(_SyncStatus(0.1, 'Loading playlists...'));
    final themeColor = Provider.of<ThemeService>(context, listen: false).themeColor;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<_SyncStatus>(
        valueListenable: statusNotifier,
        builder: (context, status, child) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Icon(Icons.sync, color: themeColor),
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
      final playlists = await widget.mediaHandler.loadPlaylists();
      statusNotifier.value = _SyncStatus(0.3, 'Preparing playlist payloads...');
      List<Map<String, dynamic>> syncPayload = [];

      for (int i = 0; i < playlists.length; i++) {
        final pl = playlists[i];
        final tracks = await widget.mediaHandler.loadPlaylistTracks(pl.playlistID);
        final trackIds = tracks.map((t) => t.trackID).toList();
        syncPayload.add({
          'playlist_id': pl.playlistID,
          'name': pl.title,
          'tracks': trackIds,
        });
        double stepProgress = 0.3 + (0.4 * (i + 1) / (playlists.isEmpty ? 1 : playlists.length));
        statusNotifier.value = _SyncStatus(stepProgress, 'Processing playlist "${pl.title}"...');
      }

      statusNotifier.value = _SyncStatus(0.8, 'Pushing to cloud server...');
      final success = await widget.serverClient.pushSyncPlaylists(syncPayload);

      statusNotifier.value = _SyncStatus(1.0, 'Sync Complete!');
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        _showAlert('Playlist Sync', 'Playlists synced to server successfully!');
      } else {
        _showAlert('Sync Error', 'Failed to push playlists to server.');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert('Sync Error', e.toString());
    } finally {
      statusNotifier.dispose();
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2B2B2B),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFB32424),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _onCreatePlaylist() async {
    await widget.mediaHandler.createPlaylist();
    await _loadPlaylists();
  }

  Future<void> _onEditPlaylistName(String newName) async {
    if (_currentPlaylist == null) return;
    await widget.mediaHandler.editPlaylistTitle(_currentPlaylist!.playlistID, newName);
    await _loadPlaylists();
    setState(() {
      _currentPlaylist = Playlist(playlistID: _currentPlaylist!.playlistID, title: newName);
    });
  }

  Future<void> _onDeletePlaylist() async {
    if (_currentPlaylist == null) return;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Confirm',
      message: 'Are you sure you want to delete ${_currentPlaylist!.title}?',
    );
    if (confirmed == true) {
      await widget.mediaHandler.deletePlaylist(_currentPlaylist!.playlistID);
      setState(() {
        _currentPlaylist = null;
        _tracks = [];
      });
      await _loadPlaylists();
    }
  }

  void _onShufflePressed() {
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    audioService.setShuffle();
    setState(() {});
  }

  void _onPlayTrack(Track track) {
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    audioService.clearPlaylistQueue();
    final idx = _tracks.indexOf(track);
    for (int i = idx + 1; i < _tracks.length; i++) {
      audioService.addToPlaylistQueue(_tracks[i]);
    }
    audioService.play(track);
  }

  void _onDownloadTrack(Track track) async {
    await widget.serverClient.downloadTrack(track);
    track.downloaded = true;
    if (_currentPlaylist != null) {
      await _loadPlaylistTracks(_currentPlaylist!);
    }
    setState(() {});
  }

  void _onRemoveDownloadTrack(Track track) async {
    await widget.serverClient.removeDownload(track);
    track.downloaded = false;
    if (_currentPlaylist != null) {
      await _loadPlaylistTracks(_currentPlaylist!);
    } else {
      final tracks = await widget.mediaHandler.getAllTracks();
      setState(() {
        _tracks = tracks;
      });
    }
    setState(() {});
  }

  void _onQueueTrack(Track track) {
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    audioService.addToQueue(track);
  }

  Future<void> _onTogglePlaylist(Playlist playlist, Track track) async {
    final list = _playlistTracksMap[playlist.playlistID] ?? [];
    final isIn = list.contains(track.trackID);
    if (isIn) {
      await widget.mediaHandler.removeFromPlaylist(playlist.playlistID, track.trackID);
      list.remove(track.trackID);
    } else {
      await widget.mediaHandler.addToPlaylist(playlist.playlistID, track.trackID);
      list.add(track.trackID);
    }
    _playlistTracksMap[playlist.playlistID] = list;
    if (_currentPlaylist != null && _currentPlaylist!.playlistID == playlist.playlistID) {
      await _loadPlaylistTracks(_currentPlaylist!);
    } else {
      setState(() {});
    }
  }

  void _onOpenPlayback() async {
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
    final audioService = context.watch<AudioPlayerService>();
    final screenWidth = MediaQuery.of(context).size.width;

    final sidebarWidth = screenWidth * LayoutConstants.sidebarRatio;
    final mediaPanelWidth = screenWidth * LayoutConstants.mediaPanelRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Sidebar
          SizedBox(
            width: sidebarWidth,
            child: Sidebar(
              playlists: _playlists,
              onPlaylistSelected: _loadPlaylistTracks,
              onCreatePlaylist: _onCreatePlaylist,
              selectedPlaylistId: _currentPlaylist?.playlistID.toString(),
            ),
          ),
          // Main Panel
          Expanded(
            child: MainPanel(
              currentPlaylist: _currentPlaylist,
              tracks: _tracks,
              onSearch: _onSearch,
              onClearSearch: () => setState(() {
                _currentPlaylist = null;
                _tracks = [];
              }),
              onRlsPressed: _onRlsPressed,
              onUploadPressed: _onUploadPressed,
              onClearConfigPressed: _onClearConfigPressed,
              onSyncPressed: _onSyncPressed,
              onPlaybackPressed: _onOpenPlayback,
              onShufflePressed: _onShufflePressed,
              onEditPlaylistName: _onEditPlaylistName,
              onDeletePlaylist: _onDeletePlaylist,
              playingTrack: audioService.currentTrack,
              onPlayTrack: _onPlayTrack,
              onDownloadTrack: _serverConnection ? _onDownloadTrack : null,
              onRemoveDownloadTrack: _serverConnection ? _onRemoveDownloadTrack : null,
              onQueueTrack: _onQueueTrack,
              availablePlaylists: _playlists,
              onTogglePlaylist: _onTogglePlaylist,
              isTrackInPlaylist: (playlist, track) => (_playlistTracksMap[playlist.playlistID] ?? []).contains(track.trackID),
              isServerConnected: _serverConnection,
            ),
          ),
          // Media Panel
          SizedBox(
            width: mediaPanelWidth,
            child: const MediaPanel(),
          ),
        ],
      ),
    );
  }
}

class _SyncStatus {
  final double progress;
  final String message;
  _SyncStatus(this.progress, this.message);
}

