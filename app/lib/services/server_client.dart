import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'safe_storage.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'media_handler.dart';
import 'listening_stats_service.dart';



class SyncProgress {
  final String status;
  final double progress;
  final String? detail;

  const SyncProgress({
    required this.status,
    required this.progress,
    this.detail,
  });
}

class ServerClient {
  final http.Client _httpClient = http.Client();
  late String _appDataPath;
  final MediaHandler mediaHandler;
  final SafeStorage _storage = SafeStorage();
  
  String? appUrl;
  String? primaryUrl;
  String? fallbackUrl;
  String? appKey;
  String? userID;
  String? sessionToken;
  String? username;

  final ValueNotifier<Set<int>> downloadingTrackIdsNotifier = ValueNotifier<Set<int>>({});

  bool isTrackDownloading(int trackID) => downloadingTrackIdsNotifier.value.contains(trackID);

  ServerClient({required this.mediaHandler});

  Future<void> init() async {
    _appDataPath = mediaHandler.appDataPath;
    
    mediaHandler.onPlaylistChanged = () => pushLocalPlaylists();
    await _loadBundledConfig();
    await _loadSecureCredentials();
    await autoDetectServer();
  }

  Future<void> _loadBundledConfig() async {
    try {
      final jsonString = await rootBundle.loadString('assets/server_config.json');
      final Map<String, dynamic> config = jsonDecode(jsonString);
      primaryUrl = config['primary_url'] as String?;
      fallbackUrl = config['fallback_url'] as String?;
      appKey = config['app_key'] as String?;
    } catch (e) {
      primaryUrl = 'https://127.0.0.1:57967';
      fallbackUrl = 'https://localhost:57967';
      appKey = '';
    }
  }

  Future<void> _loadSecureCredentials() async {
    try {
      userID = await _storage.read(key: 'user_id');
      sessionToken = await _storage.read(key: 'session_token');
      username = await _storage.read(key: 'username');
      final savedAppKey = await _storage.read(key: 'app_key');
      if (savedAppKey != null && savedAppKey.isNotEmpty) {
        appKey = savedAppKey;
      }
    } catch (e) {
      print('Error loading secure credentials: $e');
    }
  }

  Future<void> _saveSecureCredentials() async {
    try {
      if (userID != null) await _storage.write(key: 'user_id', value: userID!);
      if (sessionToken != null) await _storage.write(key: 'session_token', value: sessionToken!);
      if (username != null) await _storage.write(key: 'username', value: username!);
      if (appKey != null) await _storage.write(key: 'app_key', value: appKey!);
    } catch (e) {
      print('Error saving secure credentials: $e');
    }
  }

  Future<void> logout() async {
    if (appUrl != null && sessionToken != null) {
      try {
        final targetUrl = '$appUrl/auth/logout';
        await http.post(
          Uri.parse(targetUrl),
          headers: _headers(),
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        print('Error notifying server of logout: $e');
      }
    }
    await clearRLSConfig();
  }

  Future<void> clearRLSConfig() async {
    userID = null;
    sessionToken = null;
    username = null;
    try {
      await _storage.delete(key: 'user_id');
      await _storage.delete(key: 'session_token');
      await _storage.delete(key: 'username');
    } catch (e) {
      print('Error clearing secure storage: $e');
    }
    await mediaHandler.clearAllLocalData();
  }

  Future<bool> _pingUrl(String targetUrl, {int timeoutMs = 1500}) async {
    try {
      final url = '$targetUrl/ping';
      final response = await http.get(
        Uri.parse(url),
        headers: {'AppToken': appKey ?? ''},
      ).timeout(Duration(milliseconds: timeoutMs));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> autoDetectServer({int timeoutMs = 1500}) async {
    if (primaryUrl == null) {
      appUrl = fallbackUrl;
      return appUrl != null;
    }

    if (fallbackUrl == null || fallbackUrl!.isEmpty) {
      appUrl = primaryUrl;
      return await _pingUrl(primaryUrl!, timeoutMs: timeoutMs);
    }

    print('[ServerClient] Probing primary server: $primaryUrl');
    if (await _pingUrl(primaryUrl!, timeoutMs: timeoutMs)) {
      print('[ServerClient] Primary server is reachable. Using: $primaryUrl');
      appUrl = primaryUrl;
      return true;
    }

    print('[ServerClient] Primary server check failed. Falling back to: $fallbackUrl');
    appUrl = fallbackUrl;
    return await _pingUrl(fallbackUrl!, timeoutMs: timeoutMs);
  }

  bool registered() {
    return sessionToken != null && sessionToken!.isNotEmpty && userID != null && userID!.isNotEmpty;
  }

  String get defaultDeviceName => '${Platform.operatingSystem} (${Platform.localHostname})';

  Map<String, String> _headers({bool json = false}) {
    final map = <String, String>{
      'AppToken': appKey ?? '',
      'X-Device': defaultDeviceName,
    };
    if (sessionToken != null && sessionToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $sessionToken';
    }
    if (json) {
      map['Content-Type'] = 'application/json';
    }
    return map;
  }

  Future<String?> createAndRegister(String targetUsername, String password, {String? device}) async {
    if (appUrl == null || !(await _pingUrl(appUrl!))) {
      await autoDetectServer();
    }
    final deviceName = device ?? defaultDeviceName;

    Future<String?> attemptRegister(String baseUrl) async {
      final targetUrl = '$baseUrl/auth/register';
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: _headers(json: true),
        body: jsonEncode({
          'username': targetUsername,
          'password': password,
          'device': deviceName,
        }),
      );

      if (response.statusCode == 401) return "Invalid App Token.";
      if (response.statusCode == 409) return "Username already exists.";
      if (response.statusCode != 201) return "Registration failed (${response.statusCode}).";

      final Map<String, dynamic> data = jsonDecode(response.body);
      userID = data['userID'] as String?;
      sessionToken = data['sessionToken'] as String?;
      username = targetUsername;
      appUrl = baseUrl;

      await _saveSecureCredentials();
      return null;
    }

    try {
      if (appUrl != null) {
        return await attemptRegister(appUrl!);
      }
    } catch (e) {
      if (fallbackUrl != null && appUrl != fallbackUrl) {
        try {
          return await attemptRegister(fallbackUrl!);
        } catch (_) {}
      }
      return "Connection error: $e";
    }

    return "Server unreachable.";
  }

  Future<String?> login(String targetUsername, String password, {String? device}) async {
    if (appUrl == null || !(await _pingUrl(appUrl!))) {
      await autoDetectServer();
    }
    final deviceName = device ?? defaultDeviceName;

    Future<String?> attemptLogin(String baseUrl) async {
      final targetUrl = '$baseUrl/auth/login';
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: _headers(json: true),
        body: jsonEncode({
          'username': targetUsername,
          'password': password,
          'device': deviceName,
        }),
      );

      if (response.statusCode == 401) return "Invalid credentials or App Token.";
      if (response.statusCode == 404) return "User not found.";
      if (response.statusCode != 200) return "Login failed (${response.statusCode}).";

      final Map<String, dynamic> data = jsonDecode(response.body);
      userID = data['userID'] as String?;
      sessionToken = data['sessionToken'] as String?;
      username = targetUsername;
      appUrl = baseUrl;

      await _saveSecureCredentials();
      return null;
    }

    try {
      if (appUrl != null) {
        return await attemptLogin(appUrl!);
      }
    } catch (e) {
      if (fallbackUrl != null && appUrl != fallbackUrl) {
        try {
          return await attemptLogin(fallbackUrl!);
        } catch (_) {}
      }
      return "Connection error: $e";
    }

    return "Server unreachable.";
  }

  Future<bool> validateSession() async {
    if (!registered() || appUrl == null) return false;
    try {
      final targetUrl = '$appUrl/auth/validate';
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: _headers(),
      ).timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> pushSyncPlaylists(List<Map<String, dynamic>> playlists) async {
    if (!registered() || appUrl == null) return false;
    try {
      final targetUrl = '$appUrl/sync/push';
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: _headers(json: true),
        body: jsonEncode({'playlists': playlists}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>?> pullSyncPlaylists() async {
    if (!registered() || appUrl == null) return null;
    try {
      final targetUrl = '$appUrl/sync/pull';
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> pushLocalPlaylists() async {
    if (!registered() || appUrl == null) {
      await mediaHandler.setPendingPlaylistPush(true);
      return false;
    }
    try {
      final isOnline = await ping();
      if (!isOnline) {
        await mediaHandler.setPendingPlaylistPush(true);
        return false;
      }
      final playlists = await mediaHandler.loadPlaylists();
      List<Map<String, dynamic>> syncPayload = [];

      for (var pl in playlists) {
        final tracks = await mediaHandler.loadPlaylistTracks(pl.playlistID);
        final trackIds = tracks.map((t) => t.trackID).toList();
        syncPayload.add({
          'playlist_id': pl.playlistID,
          'name': pl.title,
          'tracks': trackIds,
        });
      }
      final success = await pushSyncPlaylists(syncPayload);
      if (success) {
        await mediaHandler.setPendingPlaylistPush(false);
      } else {
        await mediaHandler.setPendingPlaylistPush(true);
      }
      return success;
    } catch (e) {
      print('Error pushing local playlists: $e');
      await mediaHandler.setPendingPlaylistPush(true);
      return false;
    }
  }

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<bool> performPullSync({void Function(SyncProgress progress)? onProgress}) async {
    if (!registered() || appUrl == null || _isSyncing) {
      onProgress?.call(const SyncProgress(status: 'Not registered, server missing, or sync in progress', progress: 1.0));
      return false;
    }

    _isSyncing = true;
    try {
      onProgress?.call(const SyncProgress(status: 'Connecting to server...', progress: 0.05));

      final isOnline = await ping();
      if (!isOnline) {
        print('Offline or server unreachable: Skipping startup pull sync.');
        onProgress?.call(const SyncProgress(status: 'Server unreachable', progress: 1.0));
        return false;
      }

      // Process pending offline download tracking
      final pendingDownloads = await mediaHandler.getPendingDownloads();
      for (final trackId in pendingDownloads) {
        try {
          await _updateDownloads(trackId);
          await mediaHandler.clearPendingDownload(trackId);
        } catch (_) {}
      }

      final pendingRemoves = await mediaHandler.getPendingRemoveDownloads();
      for (final trackId in pendingRemoves) {
        try {
          await _updateRemoveDownloads(trackId);
          await mediaHandler.clearPendingRemoveDownload(trackId);
        } catch (_) {}
      }

      // Process pending offline playlist changes
      final hasPendingPush = await mediaHandler.hasPendingPlaylistPush();
      if (hasPendingPush) {
        onProgress?.call(const SyncProgress(status: 'Pushing pending playlist updates...', progress: 0.10));
        await pushLocalPlaylists();
      }

      onProgress?.call(const SyncProgress(status: 'Checking remote downloads...', progress: 0.15));
      final serverTracks = await getUserDownloadedTracks();
      if (serverTracks != null) {
        final serverTrackIds = serverTracks.map((t) => t.trackID).toSet();
        final localTracks = await mediaHandler.getAllTracks();
        final localTrackIds = localTracks.map((t) => t.trackID).toSet();

        final tracksToDownload = serverTracks.where((st) => !localTrackIds.contains(st.trackID)).toList();
        final tracksToRemove = localTracks.where((lt) => !serverTrackIds.contains(lt.trackID)).toList();

        final totalTrackOps = tracksToDownload.length + tracksToRemove.length;
        int completedOps = 0;

        const int concurrency = 2;
        for (int i = 0; i < tracksToDownload.length; i += concurrency) {
          final chunk = tracksToDownload.sublist(
            i,
            (i + concurrency > tracksToDownload.length) ? tracksToDownload.length : i + concurrency,
          );
          final progressVal = 0.20 + (0.50 * (completedOps / (totalTrackOps > 0 ? totalTrackOps : 1)));
          onProgress?.call(SyncProgress(
            status: 'Downloading tracks (${i + 1}-${i + chunk.length}/${tracksToDownload.length})',
            detail: chunk.map((t) => t.title).join(', '),
            progress: progressVal,
          ));
          await Future.wait(chunk.map((st) => downloadTrack(st, updateServerTracking: false)));
          completedOps += chunk.length;
        }

        for (int i = 0; i < tracksToRemove.length; i++) {
          final lt = tracksToRemove[i];
          final progressVal = 0.20 + (0.50 * (completedOps / (totalTrackOps > 0 ? totalTrackOps : 1)));
          onProgress?.call(SyncProgress(
            status: 'Removing track (${i + 1}/${tracksToRemove.length})',
            detail: '${lt.title} - ${lt.artist}',
            progress: progressVal,
          ));
          await removeDownload(lt, updateServerTracking: false);
          completedOps++;
        }
      }

      onProgress?.call(const SyncProgress(status: 'Syncing playlists...', progress: 0.75));
      final serverPlaylists = await pullSyncPlaylists();
      if (serverPlaylists != null) {
        final hasUnsyncedLocal = await mediaHandler.syncLocalPlaylists(serverPlaylists);
        if (hasUnsyncedLocal) {
          await pushLocalPlaylists();
        }
      }

      onProgress?.call(const SyncProgress(status: 'Syncing listening history...', progress: 0.90));
      await ListeningStatsService.instance.syncLocalHistoryToServer(this);

      onProgress?.call(const SyncProgress(status: 'Sync complete!', progress: 1.0));
      await Future.delayed(const Duration(milliseconds: 300));

      return true;
    } catch (e) {
      print('Error performing pull sync: $e');
      onProgress?.call(SyncProgress(status: 'Sync failed: $e', progress: 1.0));
      await Future.delayed(const Duration(milliseconds: 500));
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<List<Track>?> getUserDownloadedTracks() async {
    if (!registered() || appUrl == null) return null;
    try {
      final targetUrl = '$appUrl/sync/user_downloads';
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Track(
          trackID: json['trackID'] as int,
          title: json['title'] as String,
          artist: json['artist'] as String,
          duration: json['duration'] as String,
          downloaded: true,
          contributor: json['contributor'] as String,
        )).toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _download(String type, int id) async {
    final targetUrl = '$appUrl/tracks/$id/download/$type';
    final ext = type == 'audio' ? 'flac' : 'jpg';
    final targetLocalFile = File('$_appDataPath/$type/$id.$ext');
    final tmpFile = File('${targetLocalFile.path}.part');

    final request = http.Request('GET', Uri.parse(targetUrl))
      ..headers.addAll(_headers());

    IOSink? sink;
    try {
      final response = await _httpClient.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        if (!await tmpFile.parent.exists()) {
          await tmpFile.parent.create(recursive: true);
        }
        sink = tmpFile.openWrite();
        await sink.addStream(response.stream).timeout(const Duration(seconds: 180));
        await sink.flush();
        await sink.close();
        sink = null;
        await tmpFile.rename(targetLocalFile.path);
      } else {
        print('Download failed for $type/$id: HTTP ${response.statusCode}');
        if (await tmpFile.exists()) await tmpFile.delete();
        throw Exception('Download failed for $type/$id: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('An error occurred during transmission: $e');
      if (sink != null) {
        try { await sink.close(); } catch (_) {}
      }
      if (await tmpFile.exists()) {
        try { await tmpFile.delete(); } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> _upload(String type, String path, String id) async {
    var ext = '';
    final lastDot = path.lastIndexOf('.');
    if (lastDot >= 0) {
      ext = path.substring(lastDot + 1).toLowerCase();
    }
    if (ext != 'wav' && ext != 'mp3' && ext != 'jpg' && ext != 'png') {
      ext = type == 'audio' ? 'wav' : 'jpg';
    }
    final targetUrl = '$appUrl/tracks/$id/upload/$ext';
    final localFile = File(path);
    
    String contentType;
    if (ext == 'wav') contentType = 'audio/wav';
    else if (ext == 'mp3') contentType = 'audio/mpeg';
    else if (ext == 'png') contentType = 'image/png';
    else contentType = 'image/jpeg';

    final rawRequest = http.StreamedRequest('POST', Uri.parse(targetUrl))
      ..headers.addAll(_headers())
      ..headers['Content-Type'] = contentType;

    try {
      final length = await localFile.length();
      rawRequest.contentLength = length;
      localFile.openRead().pipe(rawRequest.sink);

      final response = await rawRequest.send().timeout(const Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString().timeout(const Duration(seconds: 60));
      if (response.statusCode == 201) {
        print('Upload succeeded for $type/$id');
      } else {
        print('Upload failed for $type/$id: HTTP ${response.statusCode} - $responseBody');
        throw Exception('Upload failed for $type/$id: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('An error occurred during upload transmission: $e');
      rethrow;
    }
  }

  Future<void> _updateDownloads(int id) async {
    final targetUrl = '$appUrl/tracks/downloads/update/$id';
    await http.post(
      Uri.parse(targetUrl),
      headers: _headers(),
    ).timeout(const Duration(seconds: 8));
  }

  Future<String> _updateUploads(Track track) async {
    final targetUrl = '$appUrl/tracks/new';
    final jsonString = jsonEncode({
      'track_id': track.trackID,
      'title': track.title,
      'artist': track.artist,
      'duration': track.duration,
      'downloaded': track.downloaded,
      'contributor': track.contributor,
    });

    final response = await http.post(
      Uri.parse(targetUrl),
      headers: _headers(json: true),
      body: jsonString,
    ).timeout(const Duration(seconds: 10));
    return response.body;
  }

  Future<void> _updateRemoveDownloads(int id) async {
    final targetUrl = '$appUrl/tracks/downloads/remove/$id';
    await http.post(
      Uri.parse(targetUrl),
      headers: _headers(),
    ).timeout(const Duration(seconds: 8));
  }

  Future<void> removeAllTrackedDownloadsServerSide() async {
    if (!registered() || appUrl == null) return;
    try {
      final targetUrl = '$appUrl/tracks/downloads/clear_all';
      await http.post(
        Uri.parse(targetUrl),
        headers: _headers(),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      print('Clear all tracked downloads server-side failed: $e');
    }
  }

  Future<bool> ping() async {
    if (appUrl != null && await _pingUrl(appUrl!)) {
      return true;
    }
    return await autoDetectServer();
  }

  Future<List<Track>> searchTracks(String filter) async {
    if (!registered() || appUrl == null) return [];
    try {
      final encodedFilter = Uri.encodeComponent(filter);
      final response = await http.get(
        Uri.parse('$appUrl/tracks/search/$encodedFilter'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Track(
          trackID: json['track_id'] as int,
          title: json['title'] as String,
          artist: json['artist'] as String,
          duration: json['duration'] as String,
          downloaded: json['downloaded'] as bool,
          contributor: json['contributor'] as String,
        )).toList();
      }
    } catch (e) {
      print('Error searching tracks: $e');
    }
    return [];
  }

  Future<bool> downloadTrack(Track track, {bool updateServerTracking = true}) async {
    final current = Set<int>.from(downloadingTrackIdsNotifier.value);
    current.add(track.trackID);
    downloadingTrackIdsNotifier.value = current;
    try {
      try {
        await _download('cover', track.trackID);
      } catch (e) {
        print('Cover download note for track ${track.trackID}: $e');
      }
      await _download('audio', track.trackID);

      if (updateServerTracking) {
        try {
          await _updateDownloads(track.trackID);
        } catch (_) {
          await mediaHandler.addPendingDownload(track.trackID);
        }
      }
      await mediaHandler.newTrack(track);
      PaintingBinding.instance.imageCache.evict(FileImage(File('$_appDataPath/cover/${track.trackID}.jpg')));
      return true;
    } catch (e) {
      print('Track download failed: $e');
      // Cleanup any partial files if download failed midway
      try {
        final flacFile = File('$_appDataPath/audio/${track.trackID}.flac');
        final coverFile = File('$_appDataPath/cover/${track.trackID}.jpg');
        if (await flacFile.exists()) await flacFile.delete();
        if (await coverFile.exists()) await coverFile.delete();
      } catch (_) {}
      return false;
    } finally {
      final updated = Set<int>.from(downloadingTrackIdsNotifier.value);
      updated.remove(track.trackID);
      downloadingTrackIdsNotifier.value = updated;
    }
  }

  Future<void> uploadTrack(Track track, String audioPath, String coverPath) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(audioPath);
      if (duration != null) {
        final totalSeconds = duration.inSeconds;
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;
        track.duration = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      print('Error calculating audio duration: $e');
    } finally {
      await player.dispose();
    }

    try {
      final newId = await _updateUploads(track);
      await _upload('audio', audioPath, newId);
      await _upload('cover', coverPath, newId);
    } catch (e) {
      print('Track upload failed: $e');
    }
  }

  Future<bool> removeDownload(Track track, {bool updateServerTracking = true}) async {
    final wavFile = File('$_appDataPath/audio/${track.trackID}.wav');
    final flacFile = File('$_appDataPath/audio/${track.trackID}.flac');
    final coverFile = File('$_appDataPath/cover/${track.trackID}.jpg');

    bool filesDeleted = true;
    try {
      PaintingBinding.instance.imageCache.evict(FileImage(coverFile));
      if (await wavFile.exists()) await wavFile.delete();
      if (await flacFile.exists()) await flacFile.delete();
      if (await coverFile.exists()) await coverFile.delete();
    } catch (e) {
      print('Error deleting track asset files: $e');
      filesDeleted = false;
    }
    
    await mediaHandler.deleteTrack(track);

    if (updateServerTracking) {
      try {
        await _updateRemoveDownloads(track.trackID);
      } catch (e) {
        print('Remove track from downloads failed: $e');
        await mediaHandler.addPendingRemoveDownload(track.trackID);
      }
    }

    return filesDeleted;
  }

  Future<bool> syncHistoryToServer(List<Map<String, dynamic>> historyItems) async {
    if (!registered() || appUrl == null || historyItems.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('$appUrl/history/sync'),
        headers: _headers(json: true),
        body: jsonEncode({'history': historyItems}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchServerStats() async {
    if (!registered() || appUrl == null || userID == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$appUrl/stats/$userID'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching server stats: $e');
    }
    return null;
  }

  Future<bool> ackServerStats() async {
    if (!registered() || appUrl == null || userID == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$appUrl/stats/ack/$userID'),
        headers: _headers(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
