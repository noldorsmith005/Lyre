import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import 'listening_stats_service.dart';
import 'server_client.dart';



class LyreAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player;
  AudioPlayerService? _service;
  final List<StreamSubscription> _subscriptions = [];

  LyreAudioHandler(this._player) {
    _subscriptions.add(_player.playbackEventStream.listen((PlaybackEvent event) {
      _updatePlaybackState();
    }));

    _subscriptions.add(_player.playerStateStream.listen((PlayerState state) {
      _updatePlaybackState();
    }));

    _subscriptions.add(_player.positionStream.listen((position) {
      _updatePlaybackState();
    }));

    _subscriptions.add(_player.durationStream.listen((duration) {
      if (mediaItem.value != null && duration != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    }));
  }

  Future<void> disposeSubscriptions() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  void _updatePlaybackState() {
    final playing = _player.playing;
    final processingState = const {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[_player.processingState] ?? AudioProcessingState.idle;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.setRepeatMode,
        MediaAction.setShuffleMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      repeatMode: _service?.loop == true ? AudioServiceRepeatMode.one : AudioServiceRepeatMode.none,
      shuffleMode: _service?.shuffle == true ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    ));
  }

  void attachService(AudioPlayerService service) {
    _service = service;
  }

  void updateTrackMediaItem(Track track, String appDataPath) {
    File artFile = File('$appDataPath/cover/${track.trackID}.jpg');
    if (!artFile.existsSync()) {
      artFile = File('$appDataPath/artwork/${track.trackID}.jpg');
    }
    Uri? artUri;
    if (artFile.existsSync()) {
      artUri = Uri.file(artFile.path);
    }

    Duration parsedDuration = Duration.zero;
    try {
      final parts = track.duration.split(':');
      if (parts.length == 2) {
        parsedDuration = Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
      } else if (parts.length == 3) {
        parsedDuration = Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]), seconds: int.parse(parts[2]));
      }
    } catch (_) {}

    mediaItem.add(MediaItem(
      id: track.trackID.toString(),
      album: track.artist,
      title: track.title,
      artist: track.artist,
      artUri: artUri,
      duration: parsedDuration.inMilliseconds > 0 ? parsedDuration : _player.duration,
    ));
    _updatePlaybackState();
  }

  void clearMediaItem() {
    mediaItem.add(null);
    _updatePlaybackState();
  }

  @override
  Future<void> play() async {
    if (_service != null) {
      await _service!.resume();
    } else {
      await _player.play();
    }
    _updatePlaybackState();
  }

  @override
  Future<void> pause() async {
    if (_service != null) {
      await _service!.pause();
    } else {
      await _player.pause();
    }
    _updatePlaybackState();
  }

  @override
  Future<void> stop() async {
    if (_service != null) {
      await _service!.stopAndClear();
    } else {
      await _player.stop();
    }
    _updatePlaybackState();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _updatePlaybackState();
  }

  @override
  Future<void> skipToNext() async {
    if (_service != null) {
      _service!.next();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_service != null) {
      _service!.previous();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (_service != null) {
      _service!.toggleLoop(repeatMode == AudioServiceRepeatMode.one || repeatMode == AudioServiceRepeatMode.all);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (_service != null) {
      _service!.setShuffle(shuffleMode == AudioServiceShuffleMode.all || shuffleMode == AudioServiceShuffleMode.group);
    }
  }
}

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  LyreAudioHandler? _audioHandler;
  StreamSubscription? _stateSubscription;
  Track? currentTrack;
  bool isPlaying = false;
  Timer? _playTimer;
  bool _shuffle = false;
  bool get shuffle => _shuffle;
  set shuffle(bool value) {
    _shuffle = value;
    _audioHandler?._updatePlaybackState();
    notifyListeners();
  }

  bool _loop = false;
  bool get loop => _loop;
  set loop(bool value) {
    _loop = value;
    _audioHandler?._updatePlaybackState();
    notifyListeners();
  }

  List<Track> queue = [];
  List<Track> nextUp = [];
  List<Track> _unshuffledNextUp = [];
  String? _appDataPath;
  ProcessingState _lastProcessingState = ProcessingState.idle;
  int _loadedPlayRequestId = 0;

  String? get appDataPath => _appDataPath;

  final Completer<void> _initCompleter = Completer<void>();
  bool _isInitStarted = false;
  bool _isInitDone = false;
  int _playRequestId = 0;

  AudioPlayerService() {
    init();
  }

  Future<void> init() async {
    if (_isInitStarted || _isInitDone) return _initCompleter.future;
    _isInitStarted = true;
    try {
      if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        _appDataPath = '$home/Library/Application Support/Lyre';
      } else if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        _appDataPath = '$appData/Lyre';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        _appDataPath = '${dir.path}/Lyre';
      }

      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());

        _audioHandler = await AudioService.init(
          builder: () => LyreAudioHandler(_player),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.nategartland.lyre.audio',
            androidNotificationChannelName: 'Lyre Audio Playback',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            androidNotificationIcon: 'mipmap/ic_launcher',
          ),
        );
        _audioHandler?.attachService(this);
      } catch (e) {
        debugPrint('AudioService init error: $e');
      }

      _stateSubscription = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && 
            _lastProcessingState != ProcessingState.completed) {
          if (_loadedPlayRequestId == _playRequestId) {
            _onTrackCompleted();
          }
        }
        _lastProcessingState = state.processingState;
        isPlaying = state.playing;
        _audioHandler?._updatePlaybackState();
        notifyListeners();
      });
    } finally {
      _isInitDone = true;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  void _onTrackCompleted() {
    if (loop && currentTrack != null) {
      final audioFile = _getAudioFile(currentTrack!.trackID);
      if (audioFile != null) {
        _player.seek(Duration.zero);
        _player.play();
        _playTimer?.cancel();
        _playTimer = Timer(const Duration(seconds: 30), () {
          if (currentTrack != null && isPlaying) {
            ListeningStatsService.instance.logPlay(currentTrack!);
          }
        });
        _audioHandler?._updatePlaybackState();
        notifyListeners();
        return;
      }
    }
    next(ignoreLoop: true);
  }

  File? _getAudioFile(int trackId) {
    if (_appDataPath == null) return null;
    final flac = File('$_appDataPath/audio/$trackId.flac');
    if (flac.existsSync() && flac.lengthSync() > 0) return flac;
    return null;
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Duration get currentTrackDuration {
    if (_player.duration != null && _player.duration! > Duration.zero) {
      return _player.duration!;
    }
    if (currentTrack != null && currentTrack!.duration.isNotEmpty) {
      try {
        final parts = currentTrack!.duration.split(':');
        if (parts.length == 2) {
          return Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
        } else if (parts.length == 3) {
          return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]), seconds: int.parse(parts[2]));
        }
      } catch (_) {}
    }
    return Duration.zero;
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _playTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  ServerClient? serverClient;

  Future<void> play(Track track, {ServerClient? serverClient}) async {
    if (!_isInitDone) {
      await _initCompleter.future;
    }
    if (_appDataPath == null) return;

    final currentRequestId = ++_playRequestId;

    try {
      final file = _getAudioFile(track.trackID);
      if (file == null) {
        debugPrint('Audio file not found for track ${track.trackID} (${track.title}). Auto-skipping...');
        if (currentRequestId != _playRequestId) return;
        if (queue.isNotEmpty || nextUp.isNotEmpty) {
          next(ignoreLoop: true);
        } else {
          currentTrack = null;
          isPlaying = false;
          _player.stop();
          _audioHandler?.clearMediaItem();
          notifyListeners();
        }
        return;
      }

      if (currentRequestId != _playRequestId) return;

      currentTrack = track;
      isPlaying = true;
      if (_appDataPath != null) {
        _audioHandler?.updateTrackMediaItem(track, _appDataPath!);
      }
      notifyListeners();

      try {
        final session = await AudioSession.instance;
        await session.setActive(true);
      } catch (_) {}

      if (currentRequestId != _playRequestId) return;

      // preferPreciseDurationAndTiming forces AVFoundation to build a sample
      // table instead of estimating time<->byte offsets from average bitrate.
      // Our FLACs carry no SEEKTABLE, so without this a seek on macOS/iOS lands
      // seconds away from the requested position and the seek bar runs ahead of
      // the audio. Ignored on Android, where ExoPlayer seeks accurately anyway.
      await _player.setAudioSource(
        ProgressiveAudioSource(
          Uri.file(file.path),
          options: const ProgressiveAudioSourceOptions(
            darwinAssetOptions: DarwinAssetOptions(
              preferPreciseDurationAndTiming: true,
            ),
          ),
        ),
      );
      if (currentRequestId != _playRequestId) return;
      
      _loadedPlayRequestId = currentRequestId;

      if (_appDataPath != null) {
        _audioHandler?.updateTrackMediaItem(track, _appDataPath!);
      }
      await _player.play();
      
      _playTimer?.cancel();
      _playTimer = Timer(const Duration(seconds: 30), () {
        if (currentTrack?.trackID == track.trackID && isPlaying) {
          ListeningStatsService.instance.logPlay(track);
        }
      });
    } catch (e) {
      debugPrint('Error playing audio for track ${track.trackID}: $e');
      if (currentRequestId == _playRequestId) {
        if (queue.isNotEmpty || nextUp.isNotEmpty) {
          next(ignoreLoop: true);
        } else {
          currentTrack = null;
          isPlaying = false;
          _player.stop();
          _audioHandler?.clearMediaItem();
          notifyListeners();
        }
      }
    }
  }

  void playTrackInContext(Track track, List<Track> contextTracks) {
    clearNextUp();
    _unshuffledNextUp.clear();
    final downloadedTracks = contextTracks.where((t) => t.downloaded || (_appDataPath != null && File('$_appDataPath/audio/${t.trackID}.flac').existsSync())).toList();
    final idx = downloadedTracks.indexWhere((t) => t.trackID == track.trackID);
    if (idx != -1) {
      if (shuffle) {
        final otherTracks = downloadedTracks.where((t) => t.trackID != track.trackID).toList();
        _unshuffledNextUp = List.from(otherTracks);
        final shuffled = List<Track>.from(otherTracks)..shuffle();
        for (final t in shuffled) {
          addToNextUp(t);
        }
      } else {
        for (int i = idx + 1; i < downloadedTracks.length; i++) {
          addToNextUp(downloadedTracks[i]);
        }
        _unshuffledNextUp = List.from(nextUp);
      }
    }
    play(track);
  }

  void playFromQueue(Track track) {
    removeFromQueue(track);
    play(track);
  }

  Future<void> pause() async {
    isPlaying = false;
    await _player.pause();
    _audioHandler?._updatePlaybackState();
    notifyListeners();
  }

  Future<void> resume() async {
    isPlaying = true;
    await _player.play();
    _audioHandler?._updatePlaybackState();
    notifyListeners();
  }

  Future<void> seek(double percent) async {
    final duration = currentTrackDuration;
    if (duration.inMilliseconds > 0) {
      final position = duration * percent;
      await _player.seek(position);
    }
  }

  void previous() {
    _player.seek(Duration.zero);
  }

  void next({bool ignoreLoop = false}) {
    if (queue.isNotEmpty) {
      final nextTrack = queue.removeAt(0);
      notifyListeners();
      play(nextTrack);
    } else if (nextUp.isNotEmpty) {
      final Track nextTrack = nextUp.removeAt(0);
      notifyListeners();
      play(nextTrack);
    } else if (loop && !ignoreLoop && currentTrack != null) {
      final audioFile = _getAudioFile(currentTrack!.trackID);
      if (audioFile != null) {
        _player.seek(Duration.zero);
        _player.play();
        _playTimer?.cancel();
        _playTimer = Timer(const Duration(seconds: 30), () {
          if (currentTrack != null && isPlaying) {
            ListeningStatsService.instance.logPlay(currentTrack!);
          }
        });
        _audioHandler?._updatePlaybackState();
        notifyListeners();
      } else {
        _player.stop();
        currentTrack = null;
        isPlaying = false;
        _audioHandler?.clearMediaItem();
        notifyListeners();
      }
    } else {
      _player.stop();
      currentTrack = null;
      isPlaying = false;
      _audioHandler?.clearMediaItem();
      notifyListeners();
    }
  }

  void addToQueue(Track track) {
    final hasAudio = _getAudioFile(track.trackID) != null;
    final isDownloaded = track.downloaded || hasAudio;
    if (!isDownloaded) return;
    queue.add(track);
    notifyListeners();
    if (currentTrack == null && !isPlaying) {
      next();
    }
  }

  void addToNextUp(Track track) {
    nextUp.add(track);
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

  void clearNextUp() {
    nextUp.clear();
    _unshuffledNextUp.clear();
    notifyListeners();
  }

  Future<void> stopAndClear() async {
    try {
      await _player.stop();
    } catch (_) {}
    currentTrack = null;
    isPlaying = false;
    queue.clear();
    nextUp.clear();
    _unshuffledNextUp.clear();
    _audioHandler?.clearMediaItem();
    notifyListeners();
  }

  void setShuffle([bool? value]) {
    _shuffle = value ?? !_shuffle;
    if (_shuffle) {
      if (nextUp.isNotEmpty) {
        if (_unshuffledNextUp.isEmpty) {
          _unshuffledNextUp = List.from(nextUp);
        }
        nextUp.shuffle();
      }
    } else {
      if (_unshuffledNextUp.isNotEmpty) {
        final nextUpIds = nextUp.map((t) => t.trackID).toSet();
        nextUp = _unshuffledNextUp.where((t) => nextUpIds.contains(t.trackID)).toList();
        _unshuffledNextUp.clear();
      }
    }
    _audioHandler?._updatePlaybackState();
    notifyListeners();
  }

  void toggleLoop([bool? value]) {
    loop = value ?? !loop;
    _audioHandler?._updatePlaybackState();
  }

  bool trackPlaying(Track track) {
    return currentTrack?.trackID == track.trackID;
  }
}
