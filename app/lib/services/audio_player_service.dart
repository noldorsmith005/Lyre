import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  Track? currentTrack;
  bool isPlaying = false;
  bool shuffle = false;
  bool loop = false;
  List<Track> queue = [];
  List<Track> playlist = [];
  String? _appDataPath;

  String? get appDataPath => _appDataPath;

  final VoidCallback onRefresh;

  AudioPlayerService({required this.onRefresh}) {
    _init();
  }

  Future<void> _init() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      _appDataPath = '$home/Library/Application Support/Napster';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      _appDataPath = '$appData/Napster';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _appDataPath = '${dir.path}/Napster';
    }

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
      isPlaying = state.playing;
      notifyListeners();
    });
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> play(Track track) async {
    if (_appDataPath == null) return;
    
    final file = File('$_appDataPath/audio/${track.trackID}.flac');
    if (!await file.exists()) {
      print('FLAC file not found: ${file.path}');
      return;
    }

    currentTrack = track;
    isPlaying = true;
    notifyListeners();

    try {
      await _player.setFilePath(file.path);
      await _player.play();
      onRefresh();
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> pause() async {
    isPlaying = false;
    await _player.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    isPlaying = true;
    await _player.play();
    notifyListeners();
  }

  Future<void> seek(double percent) async {
    final duration = _player.duration;
    if (duration != null) {
      final position = duration * percent;
      await _player.seek(position);
    }
  }

  void next() {
    if (loop) {
      _player.seek(Duration.zero);
      _player.play();
    } else if (queue.isNotEmpty) {
      play(queue.removeAt(0));
    } else if (playlist.isNotEmpty) {
      if (shuffle) {
        final random = Random();
        final idx = random.nextInt(playlist.length);
        play(playlist.removeAt(idx));
      } else {
        play(playlist.removeAt(0));
      }
    } else {
      _player.stop();
      isPlaying = false;
      notifyListeners();
    }
  }

  void addToQueue(Track track) {
    queue.add(track);
    notifyListeners();
  }

  void addToPlaylistQueue(Track track) {
    playlist.add(track);
    notifyListeners();
  }

  void removeFromQueue(Track track) {
    queue.removeWhere((t) => t.trackID == track.trackID);
    notifyListeners();
  }

  void clearQueue() {
    queue.clear();
    notifyListeners();
  }

  void clearPlaylistQueue() {
    playlist.clear();
    notifyListeners();
  }

  void setShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  bool isShuffled() => shuffle;

  bool trackPlaying(Track track) {
    return currentTrack?.trackID == track.trackID;
  }
}
