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
  final String stage;
  final int stepIndex;
  final int totalSteps;
  final double progress;
  final bool isDownloadingPhase;
  final int currentTrackIndex;
  final int totalTracksToDownload;
  final String? currentTrackTitle;
  final double? trackProgress;
  final String? trackProgressLabel;

  const SyncProgress({
    this.stage = '',
    this.stepIndex = 0,
    this.totalSteps = 5,
    this.progress = 0.0,
    this.isDownloadingPhase = false,
    this.currentTrackIndex = 0,
    this.totalTracksToDownload = 0,
    this.currentTrackTitle,
    this.trackProgress,
    this.trackProgressLabel,
  });
}

class TrackSourceInfo {
  final int trackID;
  final String title;
  final String artist;
  final String duration;
  final String contributor;
  final bool hidden;

  const TrackSourceInfo({
    required this.trackID,
    required this.title,
    required this.artist,
    required this.duration,
    required this.contributor,
    required this.hidden,
  });
}

class ServerClient {
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
  bool hasHiddenAccess = false;

  final ValueNotifier<Set<int>> downloadingTrackIdsNotifier = ValueNotifier<Set<int>>({});
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isOfflineNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<SyncProgress> syncProgressNotifier = ValueNotifier<SyncProgress>(const SyncProgress());

  bool isTrackDownloading(int trackID) => downloadingTrackIdsNotifier.value.contains(trackID);

  ServerClient({required this.mediaHandler});

  Future<void> init() async {
    _appDataPath = mediaHandler.appDataPath;
    
    mediaHandler.addPlaylistChangedListener(() => pushLocalPlaylists());
    await _loadBundledConfig();
    await _loadSecureCredentials();
    await autoDetectServer();
  }

  String _normalizeUrl(String? url) {
    if (url == null) return '';
    return url;
  }

  Future<void> _loadBundledConfig() async {
    try {
      final jsonString = await rootBundle.loadString('assets/server_config.json');
      final Map<String, dynamic> config = jsonDecode(jsonString);
      primaryUrl = _normalizeUrl(config['primary_url'] as String?);
      fallbackUrl = _normalizeUrl(config['fallback_url'] as String?);
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
      final savedHiddenAccess = await _storage.read(key: 'hidden_access');
      if (savedHiddenAccess != null) {
        hasHiddenAccess = savedHiddenAccess == 'true';
      }
      final savedAppKey = await _storage.read(key: 'app_key');
      if (savedAppKey != null && savedAppKey.isNotEmpty) {
        appKey = savedAppKey;
      }
    } catch (e) {
      debugPrint('Error loading secure credentials: $e');
    }
  }

  Future<void> _saveSecureCredentials() async {
    try {
      if (userID != null) await _storage.write(key: 'user_id', value: userID!);
      if (sessionToken != null) await _storage.write(key: 'session_token', value: sessionToken!);
      if (username != null) await _storage.write(key: 'username', value: username!);
      await _storage.write(key: 'hidden_access', value: hasHiddenAccess.toString());
      if (appKey != null) await _storage.write(key: 'app_key', value: appKey!);
    } catch (e) {
      debugPrint('Error saving secure credentials: $e');
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
        debugPrint('Error notifying server of logout: $e');
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
      debugPrint('Error clearing secure storage: $e');
    }
    await mediaHandler.clearAllLocalData();
  }

  Future<bool> _pingUrl(String targetUrl, {int timeoutMs = 3500}) async {
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

  Future<bool> autoDetectServer({int timeoutMs = 3500}) async {
    if (primaryUrl == null) {
      appUrl = fallbackUrl;
      return appUrl != null;
    }

    if (fallbackUrl == null || fallbackUrl!.isEmpty) {
      appUrl = primaryUrl;
      return await _pingUrl(primaryUrl!, timeoutMs: timeoutMs);
    }

    debugPrint('[ServerClient] Probing primary server: $primaryUrl');
    if (await _pingUrl(primaryUrl!, timeoutMs: timeoutMs)) {
      debugPrint('[ServerClient] Primary server is reachable. Using: $primaryUrl');
      appUrl = primaryUrl;
      return true;
    }

    debugPrint('[ServerClient] Primary server check failed. Falling back to: $fallbackUrl');
    appUrl = fallbackUrl;
    return await _pingUrl(fallbackUrl!, timeoutMs: timeoutMs);
  }

  bool registered() {
    return sessionToken != null && sessionToken!.isNotEmpty && userID != null && userID!.isNotEmpty;
  }

  String get defaultDeviceName => Platform.operatingSystem;

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
      if (data.containsKey('hiddenAccess')) {
        hasHiddenAccess = data['hiddenAccess'] == true;
      }
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
      if (data.containsKey('hiddenAccess')) {
        hasHiddenAccess = data['hiddenAccess'] == true;
      }
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
    if (!registered() || appUrl == null || !await ping()) return false;
    try {
      final targetUrl = '$appUrl/auth/validate';
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: _headers(),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data.containsKey('hiddenAccess')) {
            hasHiddenAccess = data['hiddenAccess'] == true;
            await _saveSecureCredentials();
          }
        } catch (_) {}
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> pushSyncPlaylists(List<Map<String, dynamic>> playlists) async {
    if (!registered() || appUrl == null || !await ping()) return false;
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
    if (!registered() || appUrl == null || !await ping()) return null;
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

  Future<bool> pushLocalPlaylists({bool internal = false}) async {
    if (!registered() || appUrl == null) {
      await mediaHandler.setPendingPlaylistPush(true);
      return false;
    }
    if (_isSyncing && !internal) return false;
    if (!internal) {
      _isSyncing = true;
      isSyncingNotifier.value = true;
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
      debugPrint('Error pushing local playlists: $e');
      await mediaHandler.setPendingPlaylistPush(true);
      return false;
    } finally {
      if (!internal) {
        _isSyncing = false;
        isSyncingNotifier.value = false;
      }
    }
  }

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  void _reportProgress(SyncProgress progress) {
    syncProgressNotifier.value = progress;
  }

  Future<bool> performPullSync() async {
    if (!registered() || appUrl == null || _isSyncing) return false;

    _isSyncing = true;
    isSyncingNotifier.value = true;
    try {
      _reportProgress(const SyncProgress(
        stage: 'Connecting to server...',
        stepIndex: 1,
        totalSteps: 5,
        progress: 0.05,
      ));

      final isOnline = await ping();
      if (!isOnline) {
        debugPrint('Offline or server unreachable: Skipping pull sync.');
        return false;
      }

      // Step 1: Process pending offline changes
      _reportProgress(const SyncProgress(
        stage: 'Flushing offline changes...',
        stepIndex: 1,
        totalSteps: 5,
        progress: 0.15,
      ));

      final pendingDownloads = await mediaHandler.getPendingDownloads();
      if (pendingDownloads.isNotEmpty) {
        try {
          await _batchUpdateDownloads(pendingDownloads);
          await mediaHandler.clearAllPendingDownloads();
        } catch (_) {}
      }

      final pendingRemoves = await mediaHandler.getPendingRemoveDownloads();
      if (pendingRemoves.isNotEmpty) {
        try {
          await _batchRemoveDownloads(pendingRemoves);
          await mediaHandler.clearAllPendingRemoveDownloads();
        } catch (_) {}
      }

      final hasPendingPush = await mediaHandler.hasPendingPlaylistPush();
      if (hasPendingPush) {
        await pushLocalPlaylists(internal: true);
      }

      // ── Stage 1 (Step 2/5): Database Sync ──
      _reportProgress(const SyncProgress(
        stage: 'Syncing playlists & metadata...',
        stepIndex: 2,
        totalSteps: 5,
        progress: 0.30,
      ));

      // 1. Fetch server track metadata manifest and upsert into DB for all tracks.
      final serverTracks = await getUserDownloadedTracks();
      final serverTrackIds = <int>{};
      if (serverTracks != null) {
        for (final st in serverTracks) {
          serverTrackIds.add(st.trackID);
          await mediaHandler.upsertTrackMetadata(st);
        }
      }

      // 2. Sync playlists from server.
      final serverPlaylists = await pullSyncPlaylists();
      if (serverPlaylists != null) {
        final hasUnsyncedLocal = await mediaHandler.syncLocalPlaylists(serverPlaylists);
        if (hasUnsyncedLocal) {
          await pushLocalPlaylists(internal: true);
        }
      }

      // 3. Sync history
      await ListeningStatsService.instance.syncLocalHistoryToServer(this);

      // Reload cache and notify UI so new database tracks appear right away!
      await mediaHandler.loadAllIntoMemory();
      mediaHandler.notifyPlaylistChanged();

      // ── Stage 2 (Step 3/5): Remove Stale Downloads ──
      _reportProgress(const SyncProgress(
        stage: 'Pruning stale downloads...',
        stepIndex: 3,
        totalSteps: 5,
        progress: 0.45,
      ));

      if (serverTrackIds.isNotEmpty) {
        final removedTracks = await mediaHandler.removeTracksNotIn(serverTrackIds);
        if (removedTracks.isNotEmpty) {
          try {
            await _batchRemoveDownloads(removedTracks.map((t) => t.trackID).toList());
          } catch (_) {}
          await mediaHandler.loadAllIntoMemory();
          mediaHandler.notifyPlaylistChanged();
        }
      }

      // ── Stage 3 (Step 4/5): Download Missing Tracks (Sequential) ──
      final undownloaded = await mediaHandler.getUndownloadedTracks();
      if (undownloaded.isEmpty) {
        _reportProgress(const SyncProgress(
          stage: 'All tracks up to date',
          stepIndex: 4,
          totalSteps: 5,
          progress: 0.85,
        ));
      } else {
        for (int i = 0; i < undownloaded.length; i++) {
          final track = undownloaded[i];
          final overallProgress = 0.45 + (0.40 * (i / undownloaded.length));
          final trackProgressFraction = (i + 1) / undownloaded.length;
          final title = track.title.isNotEmpty ? track.title : 'Track ${track.trackID}';
          final displayTitle = track.artist.isNotEmpty ? '$title • ${track.artist}' : title;

          _reportProgress(SyncProgress(
            stage: 'Downloading new tracks...',
            stepIndex: 4,
            totalSteps: 5,
            progress: overallProgress,
            isDownloadingPhase: true,
            currentTrackIndex: i + 1,
            totalTracksToDownload: undownloaded.length,
            currentTrackTitle: displayTitle,
            trackProgress: trackProgressFraction,
            trackProgressLabel: 'Track ${i + 1} of ${undownloaded.length}',
          ));

          final success = await downloadTrack(track, updateServerTracking: false);
          if (success) {
            await mediaHandler.markTrackDownloaded(track.trackID);
          }
        }
      }

      // ── Stage 4 (Step 5/5): Repair Broken Downloads & Metadata ──
      _reportProgress(const SyncProgress(
        stage: 'Checking library integrity...',
        stepIndex: 5,
        totalSteps: 5,
        progress: 0.85,
      ));

      final broken = await mediaHandler.getBrokenTracks();

      // Step 5A: Repair metadata placeholders
      if (broken.metadataBroken.isNotEmpty) {
        final serverMap = serverTracks != null
            ? {for (var t in serverTracks) t.trackID: t}
            : <int, Track>{};
        bool metadataRepaired = false;
        for (final bTrack in broken.metadataBroken) {
          Track? sTrack = serverMap[bTrack.trackID];
          if (sTrack == null || sTrack.title.isEmpty || sTrack.title == 'Track ${sTrack.trackID}') {
            final searchResults = await searchTracks(bTrack.trackID.toString());
            if (searchResults.isNotEmpty) {
              sTrack = searchResults.firstWhere((t) => t.trackID == bTrack.trackID, orElse: () => searchResults.first);
            }
          }
          if (sTrack != null && sTrack.title.isNotEmpty && sTrack.title != 'Track ${sTrack.trackID}') {
            await mediaHandler.upsertTrackMetadata(sTrack);
            metadataRepaired = true;
          }
        }
        if (metadataRepaired) {
          await mediaHandler.loadAllIntoMemory();
          mediaHandler.notifyPlaylistChanged();
        }
      }

      // Step 5B: Repair missing/corrupted audio files
      if (broken.downloadBroken.isNotEmpty) {
        for (final bTrack in broken.downloadBroken) {
          await mediaHandler.resetTrackDownloadState(bTrack.trackID);
        }
        final repairUndownloaded = await mediaHandler.getUndownloadedTracks();
        for (int i = 0; i < repairUndownloaded.length; i++) {
          final track = repairUndownloaded[i];
          final overallProgress = 0.85 + (0.10 * (i / repairUndownloaded.length));
          final trackProgressFraction = (i + 1) / repairUndownloaded.length;
          final title = track.title.isNotEmpty ? track.title : 'Track ${track.trackID}';
          final displayTitle = track.artist.isNotEmpty ? '$title • ${track.artist}' : title;

          _reportProgress(SyncProgress(
            stage: 'Repairing audio files...',
            stepIndex: 5,
            totalSteps: 5,
            progress: overallProgress,
            isDownloadingPhase: true,
            currentTrackIndex: i + 1,
            totalTracksToDownload: repairUndownloaded.length,
            currentTrackTitle: displayTitle,
            trackProgress: trackProgressFraction,
            trackProgressLabel: 'Repairing ${i + 1} of ${repairUndownloaded.length}',
          ));

          final success = await downloadTrack(track, updateServerTracking: false);
          if (success) {
            await mediaHandler.markTrackDownloaded(track.trackID);
          }
        }
      }

      _reportProgress(const SyncProgress(
        stage: 'Sync complete',
        stepIndex: 5,
        totalSteps: 5,
        progress: 1.0,
      ));
      await Future.delayed(const Duration(milliseconds: 300));

      return true;
    } catch (e) {
      debugPrint('Error performing pull sync: $e');
      return false;
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
    }
  }

  Future<List<Track>?> getUserDownloadedTracks() async {
    if (!registered() || appUrl == null || !await ping()) return null;
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

  Future<void> _download(String type, int id, {HttpClient? sharedClient}) async {
    final targetUrl = '$appUrl/tracks/$id/download/$type';
    final ext = type == 'audio' ? 'flac' : 'jpg';
    final targetLocalFile = File('$_appDataPath/$type/$id.$ext');
    final tmpFile = File('${targetLocalFile.path}.part');

    final isShared = sharedClient != null;
    final client = sharedClient ?? (HttpClient()
      ..connectionTimeout = const Duration(seconds: 45));

    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(targetUrl)).timeout(const Duration(seconds: 60));
      _headers().forEach((k, v) => request.headers.set(k, v));
      final response = await request.close().timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        if (!await tmpFile.parent.exists()) {
          await tmpFile.parent.create(recursive: true);
        }
        sink = tmpFile.openWrite();
        await sink.addStream(response).timeout(const Duration(seconds: 180));
        await sink.flush();
        await sink.close();
        sink = null;
        await tmpFile.rename(targetLocalFile.path);
      } else {
        if (await tmpFile.exists()) await tmpFile.delete();
        throw Exception('Download failed for $type/$id: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (e is! Exception || !e.toString().contains('Download failed for')) {
        debugPrint('An error occurred during transmission ($type/$id): $e');
      }
      if (sink != null) {
        try { await sink.close(); } catch (_) {}
      }
      if (await tmpFile.exists()) {
        try { await tmpFile.delete(); } catch (_) {}
      }
      rethrow;
    } finally {
      if (!isShared) client.close(force: true);
    }
  }

  Future<void> _upload(String type, String path, String id) async {
    var ext = '';
    final lastDot = path.lastIndexOf('.');
    if (lastDot >= 0) {
      ext = path.substring(lastDot + 1).toLowerCase();
    }
    if (ext != 'wav' && ext != 'mp3' && ext != 'flac' && ext != 'jpg' && ext != 'png') {
      ext = type == 'audio' ? 'flac' : 'jpg';
    }
    final targetUrl = '$appUrl/tracks/$id/upload/$ext';
    final localFile = File(path);
    
    String contentType;
    if (ext == 'wav') {
      contentType = 'audio/wav';
    } else if (ext == 'mp3') {
      contentType = 'audio/mpeg';
    } else if (ext == 'flac') {
      contentType = 'audio/flac';
    } else if (ext == 'png') {
      contentType = 'image/png';
    } else {
      contentType = 'image/jpeg';
    }

    final rawRequest = http.StreamedRequest('POST', Uri.parse(targetUrl))
      ..headers.addAll(_headers())
      ..headers['Content-Type'] = contentType;

    try {
      final length = await localFile.length();
      rawRequest.contentLength = length;
      localFile.openRead().pipe(rawRequest.sink);

      final response = await rawRequest.send().timeout(const Duration(seconds: 300));
      final responseBody = await response.stream.bytesToString().timeout(const Duration(seconds: 300));
      if (response.statusCode == 201) {
        debugPrint('Upload succeeded for $type/$id');
      } else {
        debugPrint('Upload failed for $type/$id: HTTP ${response.statusCode} - $responseBody');
        String errDetail = responseBody;
        try {
          final decoded = jsonDecode(responseBody);
          if (decoded is Map && decoded.containsKey('error')) {
            errDetail = decoded['error'].toString();
          }
        } catch (_) {}
        throw Exception('Upload failed ($type): $errDetail');
      }
    } catch (e) {
      debugPrint('An error occurred during upload transmission: $e');
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

  Future<String> _updateUploads(Track track, {bool hidden = false}) async {
    final targetUrl = '$appUrl/tracks/uploads/update';
    final jsonString = jsonEncode({
      'track_id': track.trackID,
      'title': track.title,
      'artist': track.artist,
      'duration': track.duration,
      'downloaded': track.downloaded,
      'contributor': track.contributor,
      'hidden': hidden,
    });

    final response = await http.post(
      Uri.parse(targetUrl),
      headers: _headers(json: true),
      body: jsonString,
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 201) {
      String errDetail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('error')) {
          errDetail = decoded['error'].toString();
        }
      } catch (_) {}
      throw Exception('Failed to create track: $errDetail');
    }
    return response.body.trim();
  }

  Future<void> _updateRemoveDownloads(int id) async {
    final targetUrl = '$appUrl/tracks/downloads/remove/$id';
    await http.post(
      Uri.parse(targetUrl),
      headers: _headers(),
    ).timeout(const Duration(seconds: 8));
  }

  Future<void> _batchUpdateDownloads(List<int> trackIds) async {
    if (!registered() || appUrl == null || !await ping()) return;
    final targetUrl = '$appUrl/tracks/downloads/update_batch';
    await http.post(
      Uri.parse(targetUrl),
      headers: _headers(json: true),
      body: jsonEncode({'track_ids': trackIds}),
    ).timeout(const Duration(seconds: 10));
  }

  Future<void> _batchRemoveDownloads(List<int> trackIds) async {
    if (!registered() || appUrl == null || !await ping()) return;
    final targetUrl = '$appUrl/tracks/downloads/remove_batch';
    await http.post(
      Uri.parse(targetUrl),
      headers: _headers(json: true),
      body: jsonEncode({'track_ids': trackIds}),
    ).timeout(const Duration(seconds: 10));
  }

  Future<bool> clearAllPlaylistsServerSide() async {
    if (!registered() || appUrl == null || !await ping()) return false;
    try {
      final targetUrl = '$appUrl/sync/playlists/clear_all';
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: _headers(),
      ).timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Clear all playlists server-side failed: $e');
      return false;
    }
  }

  Future<void> removeAllTrackedDownloadsServerSide() async {
    if (!registered() || appUrl == null || !await ping()) return;
    try {
      final targetUrl = '$appUrl/tracks/downloads/clear_all';
      await http.post(
        Uri.parse(targetUrl),
        headers: _headers(),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Clear all tracked downloads server-side failed: $e');
    }
  }

  Future<bool> resetServerTracking() async {
    if (!registered() || appUrl == null || !await ping()) return false;
    try {
      // Stage 1: Clear all tracked playlists and downloads for this user server-side
      await removeAllTrackedDownloadsServerSide();
      await clearAllPlaylistsServerSide();

      // Clear any pending sync queue items to prevent conflict
      await mediaHandler.clearAllPendingDownloads();
      await mediaHandler.clearAllPendingRemoveDownloads();

      // Stage 2: Bulk re-sync all playlists and downloads to the server again
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

      final playlistSuccess = await pushSyncPlaylists(syncPayload);
      if (playlistSuccess) {
        await mediaHandler.setPendingPlaylistPush(false);
      } else {
        await mediaHandler.setPendingPlaylistPush(true);
      }

      final allTracks = await mediaHandler.getAllTracks();
      final downloadedTrackIds = allTracks
          .where((t) => t.downloaded || mediaHandler.isTrackDownloaded(t.trackID))
          .map((t) => t.trackID)
          .toSet()
          .toList();

      if (downloadedTrackIds.isNotEmpty) {
        await _batchUpdateDownloads(downloadedTrackIds);
      }

      return playlistSuccess;
    } catch (e) {
      debugPrint('Reset server tracking failed: $e');
      return false;
    }
  }

  Future<bool> ping() async {
    bool online = false;
    if (appUrl != null && await _pingUrl(appUrl!)) {
      online = true;
    } else {
      online = await autoDetectServer();
    }
    isOfflineNotifier.value = !online;
    return online;
  }

  Future<List<Track>> searchTracks(String filter) async {
    if (!registered() || appUrl == null) return [];
    final cleanFilter = filter.trim();
    if (cleanFilter.isEmpty) return [];
    if (!await ping()) return [];
    try {
      final encodedFilter = Uri.encodeComponent(cleanFilter);
      final response = await http.get(
        Uri.parse('$appUrl/tracks/search/$encodedFilter'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) {
          final tid = ((json['trackID'] ?? json['track_id']) ?? 0) as int;
          final isDownloadedLocally = mediaHandler.isTrackDownloaded(tid);
          return Track(
            trackID: tid,
            title: (json['title'] ?? '') as String,
            artist: (json['artist'] ?? '') as String,
            duration: (json['duration'] ?? '') as String,
            downloaded: isDownloadedLocally,
            contributor: (json['contributor'] ?? '') as String,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error searching tracks: $e');
    }
    return [];
  }

  Future<bool> downloadTrack(Track track, {bool updateServerTracking = true, HttpClient? sharedClient}) async {
    if (!registered() || appUrl == null || !await ping()) return false;
    final current = Set<int>.from(downloadingTrackIdsNotifier.value);
    current.add(track.trackID);
    downloadingTrackIdsNotifier.value = current;
    try {
      const maxRetries = 3;
      bool success = false;

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          try {
            await _download('cover', track.trackID, sharedClient: sharedClient);
          } catch (e) {
            debugPrint('Cover download note for track ${track.trackID} (attempt $attempt): $e');
          }

          await _download('audio', track.trackID, sharedClient: sharedClient);
          success = true;
          break;
        } catch (e) {
          debugPrint('Track ${track.trackID} download attempt $attempt failed: $e');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt));
          }
        }
      }

      if (!success) {
        throw Exception('All $maxRetries download attempts failed for track ${track.trackID}');
      }

      if (updateServerTracking) {
        try {
          await _updateDownloads(track.trackID);
        } catch (_) {
          await mediaHandler.addPendingDownload(track.trackID);
        }
      }
      track.downloaded = true;
      await mediaHandler.newTrack(track, reloadCache: false, downloaded: true);
      await mediaHandler.markTrackDownloaded(track.trackID);
      PaintingBinding.instance.imageCache.evict(FileImage(File('$_appDataPath/cover/${track.trackID}.jpg')));
      return true;
    } catch (e) {
      debugPrint('Track download failed: $e');
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

  Future<void> uploadTrack(
    Track track,
    String audioPath,
    String? coverPath, {
    bool hidden = false,
    Function(double progress, String status)? onProgress,
  }) async {
    if (!registered() || appUrl == null || !await ping()) {
      throw Exception('Server unreachable.');
    }
    onProgress?.call(0.10, 'Calculating audio duration...');
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
      debugPrint('Error calculating audio duration: $e');
    } finally {
      await player.dispose();
    }

    onProgress?.call(0.25, 'Creating track record on server...');
    final newId = await _updateUploads(track, hidden: hidden);

    onProgress?.call(0.50, 'Uploading audio file...');
    await _upload('audio', audioPath, newId);

    if (coverPath != null && coverPath.isNotEmpty) {
      onProgress?.call(0.85, 'Uploading cover artwork...');
      await _upload('cover', coverPath, newId);
    }

    onProgress?.call(1.0, 'Upload complete!');
  }

  Future<bool> removeDownload(Track track, {bool updateServerTracking = true}) async {
    final flacFile = File('$_appDataPath/audio/${track.trackID}.flac');
    final coverFile = File('$_appDataPath/cover/${track.trackID}.jpg');

    bool filesDeleted = true;
    try {
      PaintingBinding.instance.imageCache.evict(FileImage(coverFile));
      if (await flacFile.exists()) await flacFile.delete();
      if (await coverFile.exists()) await coverFile.delete();
    } catch (e) {
      debugPrint('Error deleting track asset files: $e');
      filesDeleted = false;
    }
    
    await mediaHandler.deleteTrack(track);

    if (updateServerTracking) {
      if (!await ping()) {
        await mediaHandler.addPendingRemoveDownload(track.trackID);
      } else {
        try {
          await _updateRemoveDownloads(track.trackID);
        } catch (e) {
          debugPrint('Remove track from downloads failed: $e');
          await mediaHandler.addPendingRemoveDownload(track.trackID);
        }
      }
    }

    return filesDeleted;
  }

  Future<TrackSourceInfo?> getTrackSourceInfo(int trackID) async {
    if (!registered() || appUrl == null || !await ping()) {
      return null;
    }
    final targetUrl = '$appUrl/tracks/$trackID/source_info';
    try {
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: _headers(),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TrackSourceInfo(
          trackID: data['track_id'] as int? ?? trackID,
          title: data['title'] as String? ?? '',
          artist: data['artist'] as String? ?? '',
          duration: data['duration'] as String? ?? '',
          contributor: data['contributor'] as String? ?? '',
          hidden: data['hidden'] as bool? ?? false,
        );
      }
    } catch (e) {
      debugPrint('Error fetching track source info: $e');
    }
    return null;
  }

  Future<void> editTrackSource(
    Track track, {
    required String title,
    required String artist,
    String? audioPath,
    String? coverPath,
    bool? hidden,
    Function(double progress, String status)? onProgress,
  }) async {
    if (!registered() || appUrl == null || !await ping()) {
      throw Exception('Server unreachable.');
    }

    String duration = track.duration;

    if (audioPath != null && audioPath.isNotEmpty) {
      onProgress?.call(0.10, 'Calculating new audio duration...');
      final player = AudioPlayer();
      try {
        final audioDuration = await player.setFilePath(audioPath);
        if (audioDuration != null) {
          final totalSeconds = audioDuration.inSeconds;
          final minutes = totalSeconds ~/ 60;
          final seconds = totalSeconds % 60;
          duration = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        debugPrint('Error calculating audio duration: $e');
      } finally {
        await player.dispose();
      }

      onProgress?.call(0.30, 'Uploading replacement audio file...');
      await _upload('audio', audioPath, track.trackID.toString());

      // If locally downloaded, update local file
      if (track.downloaded) {
        try {
          final localAudioFlac = File('$_appDataPath/audio/${track.trackID}.flac');
          if (await localAudioFlac.exists()) await localAudioFlac.delete();
          final ext = audioPath.split('.').last.toLowerCase();
          if (ext == 'flac') {
            final sourceFile = File(audioPath);
            await sourceFile.copy('$_appDataPath/audio/${track.trackID}.flac');
          } else {
            await _download('audio', track.trackID);
          }
        } catch (e) {
          debugPrint('Error updating local audio file on edit: $e');
        }
      }
    }

    if (coverPath != null && coverPath.isNotEmpty) {
      onProgress?.call(0.60, 'Uploading replacement cover artwork...');
      await _upload('cover', coverPath, track.trackID.toString());

      // If locally cached or downloaded, update local cover file and evict cache
      try {
        final localCover = File('$_appDataPath/cover/${track.trackID}.jpg');
        PaintingBinding.instance.imageCache.evict(FileImage(localCover));
        final sourceCover = File(coverPath);
        await sourceCover.copy('$_appDataPath/cover/${track.trackID}.jpg');
        PaintingBinding.instance.imageCache.evict(FileImage(localCover));
      } catch (e) {
        debugPrint('Error updating local cover file on edit: $e');
      }
    }

    onProgress?.call(0.85, 'Updating track metadata on server...');
    final targetUrl = '$appUrl/tracks/${track.trackID}/edit';
    final editBody = jsonEncode({
      'title': title,
      'artist': artist,
      'duration': duration,
      'hidden': hidden,
    });

    final response = await http.post(
      Uri.parse(targetUrl),
      headers: _headers(json: true),
      body: editBody,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      String errDetail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('error')) {
          errDetail = decoded['error'].toString();
        }
      } catch (_) {}
      throw Exception('Failed to update track: $errDetail');
    }

    // Update in-memory & local DB
    track.title = title;
    track.artist = artist;
    track.duration = duration;
    await mediaHandler.updateTrackMetadata(track.trackID, title, artist, duration);

    onProgress?.call(1.0, 'Update complete!');
  }

  Future<void> deleteTrackFromServer(Track track) async {
    if (!registered() || appUrl == null || !await ping()) {
      throw Exception('Server unreachable.');
    }

    final targetUrl = '$appUrl/tracks/${track.trackID}';
    final response = await http.delete(
      Uri.parse(targetUrl),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      // Try POST /tracks/<id>/delete fallback
      final fallbackUrl = '$appUrl/tracks/${track.trackID}/delete';
      final fbResponse = await http.post(
        Uri.parse(fallbackUrl),
        headers: _headers(),
      ).timeout(const Duration(seconds: 10));

      if (fbResponse.statusCode != 200) {
        String errDetail = fbResponse.body;
        try {
          final decoded = jsonDecode(fbResponse.body);
          if (decoded is Map && decoded.containsKey('error')) {
            errDetail = decoded['error'].toString();
          }
        } catch (_) {}
        throw Exception('Failed to delete track on server: $errDetail');
      }
    }

    // Purge local references everywhere
    await mediaHandler.purgeTrackReferences(track.trackID);
  }

  Future<bool> syncHistoryToServer(List<Map<String, dynamic>> historyItems) async {
    if (!registered() || appUrl == null || historyItems.isEmpty || !await ping()) return false;
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

  Future<Map<String, dynamic>?> checkStatsStatus() async {
    if (!registered() || appUrl == null || userID == null || !await ping()) return null;
    try {
      final response = await http.get(
        Uri.parse('$appUrl/stats/status/$userID'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error checking stats status: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchServerStats() async {
    if (!registered() || appUrl == null || userID == null || !await ping()) return null;
    try {
      final response = await http.get(
        Uri.parse('$appUrl/stats/$userID'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching server stats: $e');
    }
    return null;
  }

  Future<bool> ackServerStats() async {
    if (!registered() || appUrl == null || userID == null || !await ping()) return false;
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
