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
import '../widgets/register_modal.dart';
import '../widgets/upload_modal.dart';
import '../widgets/confirmation_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final playlists = await widget.mediaHandler.loadPlaylists();
    setState(() {
      _playlists = playlists;
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
      RegisterModal.show(
        context,
        onSubmit: (url, token, username) async {
          try {
            await widget.serverClient.createAndRegister(url, token, username);
            setState(() {
              _serverConnection = true;
            });
            if (mounted) Navigator.of(context).pop();
          } catch (e) {
            _showAlert('Registration Error', e.toString());
          }
        },
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
      title: 'Confirm',
      message: 'Are you sure you want to clear your server configuration? You will have to re-authenticate.',
    );
    if (confirmed == true) {
      widget.serverClient.clearRLSConfig();
      setState(() {
        _serverConnection = false;
      });
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

  void _onQueueTrack(Track track) {
    final audioService = Provider.of<AudioPlayerService>(context, listen: false);
    audioService.addToQueue(track);
  }

  Future<void> _onTogglePlaylist(Playlist playlist, Track track) async {
    final isIn = await widget.mediaHandler.isInPlaylist(playlist.playlistID, track.trackID);
    if (isIn) {
      await widget.mediaHandler.removeFromPlaylist(playlist.playlistID, track.trackID);
      if (_currentPlaylist != null && _currentPlaylist!.playlistID == playlist.playlistID) {
        await _loadPlaylistTracks(_currentPlaylist!);
      }
    } else {
      await widget.mediaHandler.addToPlaylist(playlist.playlistID, track.trackID);
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
              onShufflePressed: _onShufflePressed,
              onEditPlaylistName: _onEditPlaylistName,
              onDeletePlaylist: _onDeletePlaylist,
              playingTrack: audioService.currentTrack,
              onPlayTrack: _onPlayTrack,
              onDownloadTrack: _serverConnection ? _onDownloadTrack : null,
              onQueueTrack: _onQueueTrack,
              availablePlaylists: _playlists,
              onTogglePlaylist: _onTogglePlaylist,
              isTrackInPlaylist: (playlist, track) => false,
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
