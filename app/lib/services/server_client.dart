import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'media_handler.dart';

class ServerClient {
  late String _appDataPath;
  final MediaHandler mediaHandler;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  String? appUrl;
  String? primaryUrl;
  String? fallbackUrl;
  String? appKey;
  String? userID;
  String? sessionToken;
  String? username;

  ServerClient({required this.mediaHandler});

  Future<void> init() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      _appDataPath = '$home/Library/Application Support/Napster';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      _appDataPath = '$appData/Napster';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _appDataPath = p.join(dir.path, 'Napster');
    }
    
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
      appKey = 'n8cQiw4z6oSHFixnEFK7';
    }
  }

  Future<void> _loadSecureCredentials() async {
    userID = await _storage.read(key: 'user_id');
    sessionToken = await _storage.read(key: 'session_token');
    username = await _storage.read(key: 'username');
    final savedAppKey = await _storage.read(key: 'app_key');
    if (savedAppKey != null && savedAppKey.isNotEmpty) {
      appKey = savedAppKey;
    }
  }

  Future<void> _saveSecureCredentials() async {
    if (userID != null) await _storage.write(key: 'user_id', value: userID);
    if (sessionToken != null) await _storage.write(key: 'session_token', value: sessionToken);
    if (username != null) await _storage.write(key: 'username', value: username);
    if (appKey != null) await _storage.write(key: 'app_key', value: appKey);
  }

  Future<void> logout() async {
    await clearRLSConfig();
  }

  Future<void> clearRLSConfig() async {
    userID = null;
    sessionToken = null;
    username = null;
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'session_token');
    await _storage.delete(key: 'username');
    await mediaHandler.clearAllLocalData();
  }

  Future<bool> _pingUrl(String targetUrl) async {
    try {
      final url = '$targetUrl/ping';
      final response = await http.get(
        Uri.parse(url),
        headers: {'AppToken': appKey ?? ''},
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> autoDetectServer() async {
    if (primaryUrl != null && await _pingUrl(primaryUrl!)) {
      appUrl = primaryUrl;
      return true;
    }
    if (fallbackUrl != null && await _pingUrl(fallbackUrl!)) {
      appUrl = fallbackUrl;
      return true;
    }
    appUrl = primaryUrl ?? fallbackUrl;
    return false;
  }

  bool registered() {
    return sessionToken != null && sessionToken!.isNotEmpty && userID != null && userID!.isNotEmpty;
  }

  Map<String, String> _headers({bool json = false}) {
    final map = <String, String>{
      'AppToken': appKey ?? '',
    };
    if (sessionToken != null && sessionToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $sessionToken';
    }
    if (json) {
      map['Content-Type'] = 'application/json';
    }
    return map;
  }

  Future<String?> createAndRegister(String targetUsername, String password) async {
    if (appUrl == null) await autoDetectServer();
    final targetUrl = '$appUrl/auth/register';

    try {
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: _headers(json: true),
        body: jsonEncode({
          'username': targetUsername,
          'password': password,
        }),
      );

      if (response.statusCode == 401) return "Invalid App Token.";
      if (response.statusCode == 409) return "Username already exists.";
      if (response.statusCode != 201) return "Registration failed (${response.statusCode}).";

      final Map<String, dynamic> data = jsonDecode(response.body);
      userID = data['userID'] as String?;
      sessionToken = data['sessionToken'] as String?;
      username = targetUsername;

      await _saveSecureCredentials();
      return null;
    } catch (e) {
      return "Connection error: $e";
    }
  }

  Future<String?> login(String targetUsername, String password) async {
    if (appUrl == null) await autoDetectServer();
    final targetUrl = '$appUrl/auth/login';

    try {
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: _headers(json: true),
        body: jsonEncode({
          'username': targetUsername,
          'password': password,
        }),
      );

      if (response.statusCode == 401) return "Invalid credentials or App Token.";
      if (response.statusCode == 404) return "User not found.";
      if (response.statusCode != 200) return "Login failed (${response.statusCode}).";

      final Map<String, dynamic> data = jsonDecode(response.body);
      userID = data['userID'] as String?;
      sessionToken = data['sessionToken'] as String?;
      username = targetUsername;

      await _saveSecureCredentials();
      return null;
    } catch (e) {
      return "Connection error: $e";
    }
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
      );
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
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Track>?> getUserDownloadedTracks() async {
    if (!registered() || appUrl == null) return null;
    try {
      final targetUrl = '$appUrl/sync/user_downloads';
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: _headers(),
      );
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

    try {
      final response = await http.Client().send(request);
      if (response.statusCode == 200) {
        final sink = tmpFile.openWrite();
        await response.stream.pipe(sink);
        await tmpFile.rename(targetLocalFile.path);
      } else {
        print('Download failed for $type/$id: HTTP ${response.statusCode}');
        if (await tmpFile.exists()) await tmpFile.delete();
      }
    } catch (e) {
      print('An error occurred during transmission: $e');
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

      final response = await rawRequest.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 201) {
        print('Upload succeeded for $type/$id');
      } else {
        print('Upload failed for $type/$id: HTTP ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('An error occurred during transmission: $e');
    }
  }

  Future<void> _updateDownloads(int id) async {
    final targetUrl = '$appUrl/tracks/downloads/update/$id';
    await http.post(
      Uri.parse(targetUrl),
      headers: _headers(),
    );
  }

  Future<String> _updateUploads(Track track) async {
    final targetUrl = '$appUrl/tracks/uploads/update';
    final jsonString = jsonEncode({
      'trackID': track.trackID,
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
    );
    return response.body;
  }

  Future<void> _updateRemoveDownloads(int id) async {
    final targetUrl = '$appUrl/tracks/downloads/remove/$id';
    await http.post(
      Uri.parse(targetUrl),
      headers: _headers(),
    );
  }

  Future<void> removeAllTrackedDownloadsServerSide() async {
    if (!registered() || appUrl == null) return;
    try {
      final targetUrl = '$appUrl/tracks/downloads/clear_all';
      await http.post(
        Uri.parse(targetUrl),
        headers: _headers(),
      );
    } catch (e) {
      print('Clear all tracked downloads server-side failed: $e');
    }
  }

  Future<bool> ping() async {
    if (appUrl == null) await autoDetectServer();
    if (appUrl == null) return false;
    return _pingUrl(appUrl!);
  }

  Future<List<Track>> searchTracks(String filter) async {
    final encodedFilter = Uri.encodeComponent(filter);
    final targetUrl = '$appUrl/tracks/$encodedFilter';
    final response = await http.get(
      Uri.parse(targetUrl),
      headers: _headers(),
    );

    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((json) => Track(
      trackID: json['trackID'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      duration: json['duration'] as String,
      downloaded: json['downloaded'] as bool,
      contributor: json['contributor'] as String,
    )).toList();
  }

  Future<void> downloadTrack(Track track, {bool updateServerTracking = true}) async {
    try {
      await _download('audio', track.trackID);
      await _download('cover', track.trackID);
      if (updateServerTracking) {
        await _updateDownloads(track.trackID);
      }
      await mediaHandler.newTrack(track);
    } catch (e) {
      print('Track download failed.');
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
      await player.dispose();
      
      final newId = await _updateUploads(track);
      await _upload('audio', audioPath, newId);
      await _upload('cover', coverPath, newId);
    } catch (e) {
      print('Track upload failed: $e');
    }
  }

  Future<void> removeDownload(Track track, {bool updateServerTracking = true}) async {
    final wavFile = File('$_appDataPath/audio/${track.trackID}.wav');
    final flacFile = File('$_appDataPath/audio/${track.trackID}.flac');
    final coverFile = File('$_appDataPath/cover/${track.trackID}.jpg');

    try {
      if (await wavFile.exists()) await wavFile.delete();
      if (await flacFile.exists()) await flacFile.delete();
      if (await coverFile.exists()) await coverFile.delete();
    } catch (e) {
      print('Error deleting track asset files.');
    }
    
    await mediaHandler.deleteTrack(track);

    if (updateServerTracking) {
      try {
        await _updateRemoveDownloads(track.trackID);
      } catch (e) {
        print('Remove track from downloads failed.');
      }
    }
  }

  Future<bool> syncHistoryToServer(List<Map<String, dynamic>> historyItems) async {
    if (!registered() || appUrl == null || historyItems.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('$appUrl/history/sync'),
        headers: _headers(json: true),
        body: jsonEncode({'history': historyItems}),
      );
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
