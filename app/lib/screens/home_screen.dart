import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/media_handler.dart';
import '../services/server_client.dart';
import '../services/audio_player_service.dart';
import '../utils/layout_constants.dart';
import '../widgets/sidebar.dart';
import '../widgets/main_panel.dart';
import '../widgets/media_panel.dart';
import 'login_screen.dart';
import 'playback_screen.dart';
import '../widgets/upload_modal.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/vibe_queue_modal.dart';
import '../services/vibe_queue_service.dart';
import '../services/listening_stats_service.dart';



class HomeScreen extends StatefulWidget {
  final MediaHandler mediaHandler;
  final ServerClient serverClient;

  const HomeScreen({
    super.key,
    required this.mediaHandler,
    required this.serverClient,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Playlist> _playlists = [];
  List<Track> _tracks = [];
  Playlist? _currentPlaylist;
  bool _serverConnection = false;
  Map<int, List<int>> _playlistTracksMap = {};

  String _searchQuery = '';
  bool _isSearching = false;
  Timer? _searchDebounce;

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
    _searchDebounce?.cancel();
    widget.serverClient.isSyncingNotifier.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    if (!widget.serverClient.isSyncingNotifier.value && mounted) {
      _loadPlaylists();
      if (_searchQuery.trim().isNotEmpty) {
        _onSearch(_searchQuery);
      } else if (_currentPlaylist != null) {
        _loadPlaylistTracks(_currentPlaylist!);
      }
    }
  }

  bool _isAutoConnecting = false;
  DateTime? _lastSyncTime;

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
        }
      }
    } finally {
      _isAutoConnecting = false;
    }
  }

  void _showLoginScreen() {
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
            if (mounted) {
              await _loadPlaylists();
              if (_searchQuery.trim().isNotEmpty) {
                await _onSearch(_searchQuery);
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _loadPlaylists() async {
    try {
      final playlists = await widget.mediaHandler.loadPlaylists();
      final Map<int, List<int>> map = {};
      for (final pl in playlists) {
        final tracks = await widget.mediaHandler.loadPlaylistTracks(pl.playlistID);
        map[pl.playlistID] = tracks.map((t) => t.trackID).toList();
      }
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _playlistTracksMap = map;
        });
      }
    } catch (e) {
      debugPrint('Error loading playlists: $e');
    }
  }

  Future<void> _loadPlaylistTracks(Playlist playlist) async {
    try {
      widget.mediaHandler.bringPlaylistToFront(playlist.playlistID);
      final tracks = await widget.mediaHandler.loadPlaylistTracks(playlist.playlistID);
      if (mounted) {
        setState(() {
          _currentPlaylist = playlist;
          _tracks = tracks;
        });
      }
    } catch (e) {
      debugPrint('Error loading playlist tracks: $e');
    }
  }

  Future<void> _onSearch(String query) async {
    _searchQuery = query;
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
      if (_currentPlaylist != null) {
        await _loadPlaylistTracks(_currentPlaylist!);
      } else {
        setState(() {
          _tracks = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    if (_serverConnection) {
      _searchDebounce = Timer(const Duration(milliseconds: 1000), () async {
        if (!mounted) return;
        try {
          final results = await widget.serverClient.searchTracks(query);
          if (mounted && _searchQuery == query) {
            setState(() {
              _currentPlaylist = null;
              _tracks = results;
            });
          }
        } finally {
          if (mounted && _searchQuery == query) {
            setState(() {
              _isSearching = false;
            });
          }
        }
      });
    } else {
      try {
        final results = await widget.mediaHandler.searchTracks(query);
        if (mounted && _searchQuery == query) {
          setState(() {
            _currentPlaylist = null;
            _tracks = results;
          });
        }
      } finally {
        if (mounted && _searchQuery == query) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    }
  }

  void _onRlsPressed() async {
    if (!_serverConnection && !widget.serverClient.registered()) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            mediaHandler: widget.mediaHandler,
            serverClient: widget.serverClient,
            onLoginSuccess: () async {
              setState(() {
                _serverConnection = true;
              });
              if (mounted) {
                await _loadPlaylists();
                if (_searchQuery.trim().isNotEmpty) {
                  await _onSearch(_searchQuery);
                }
              }
            },
          ),
        ),
      );
    } else {
      final newConn = !_serverConnection;
      setState(() {
        _serverConnection = newConn;
      });
      if (mounted && _searchQuery.trim().isNotEmpty) {
        await _onSearch(_searchQuery);
      }
    }
  }

  void _onUploadPressed() {
    UploadModal.show(
      context,
      hasHiddenAccess: widget.serverClient.hasHiddenAccess,
      onUpload: (title, artist, mediaPath, coverPath, hidden, updateProgress) async {
        final newTrack = Track(
          trackID: 0,
          title: title,
          artist: artist,
          duration: '',
        );
        await widget.serverClient.uploadTrack(
          newTrack,
          mediaPath,
          coverPath,
          hidden: hidden,
          onProgress: updateProgress,
        );
      },
    );
  }

  void _onClearConfigPressed() async {
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
    audioService.playTrackInContext(track, _tracks);
  }

  void _onDownloadTrack(Track track) async {
    final success = await widget.serverClient.downloadTrack(track);
    if (success) {
      track.downloaded = true;
      if (_currentPlaylist != null) {
        await _loadPlaylistTracks(_currentPlaylist!);
      }
      _showSnackBar('Downloaded');
      setState(() {});
    } else {
      _showSnackBar('Track download failed or is unavailable on server.', isError: true);
    }
  }

  void _onRemoveDownloadTrack(Track track) async {
    final success = await widget.serverClient.removeDownload(track);
    if (!success) {
      _showSnackBar('Failed to remove download on server.', isError: true);
    }
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

  void _onOpenVibeQueue() {
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

  void _onReorderTrack(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _tracks.length) return;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    setState(() {
      final item = _tracks.removeAt(oldIndex);
      _tracks.insert(newIndex, item);
    });

    if (_currentPlaylist != null) {
      final trackIds = _tracks.map((t) => t.trackID).toList();
      await widget.mediaHandler.reorderPlaylistTracks(_currentPlaylist!.playlistID, trackIds);
      if (_serverConnection) {
        await widget.serverClient.pushLocalPlaylists();
      }
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
              isSearching: _isSearching,
              onClearSearch: () => setState(() {
                _searchQuery = '';
                _isSearching = false;
                _currentPlaylist = null;
                _tracks = [];
              }),
              onRlsPressed: _onRlsPressed,
              onUploadPressed: _onUploadPressed,
              onClearConfigPressed: _onClearConfigPressed,
              onPlaybackPressed: _onOpenPlayback,
              onVibeQueuePressed: _onOpenVibeQueue,
              onShufflePressed: _onShufflePressed,
              onEditPlaylistName: _onEditPlaylistName,
              onDeletePlaylist: _onDeletePlaylist,
              playingTrack: audioService.currentTrack,
              onPlayTrack: _onPlayTrack,
              onDownloadTrack: _onDownloadTrack,
              onRemoveDownloadTrack: _onRemoveDownloadTrack,
              onQueueTrack: _onQueueTrack,
              availablePlaylists: _playlists,
              onTogglePlaylist: _onTogglePlaylist,
              isTrackInPlaylist: (playlist, track) => (_playlistTracksMap[playlist.playlistID] ?? []).contains(track.trackID),
              isServerConnected: _serverConnection,
              serverClient: widget.serverClient,
              onReorderTrack: _onReorderTrack,
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

