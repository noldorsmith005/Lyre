import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import 'listening_stats_service.dart';
import 'dart:math';



class MediaHandler {
  late Database _db;
  late String _appDataPath;
  VoidCallback? onPlaylistChanged;
  final List<VoidCallback> _playlistChangedListeners = [];

  void addPlaylistChangedListener(VoidCallback listener) {
    if (!_playlistChangedListeners.contains(listener)) {
      _playlistChangedListeners.add(listener);
    }
  }

  void removePlaylistChangedListener(VoidCallback listener) {
    _playlistChangedListeners.remove(listener);
  }

  void notifyPlaylistChanged() {
    onPlaylistChanged?.call();
    for (final listener in List.of(_playlistChangedListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error in playlist change listener: $e');
      }
    }
  }

  List<Playlist> _cachedPlaylists = [];
  List<Track> _cachedAllTracks = [];
  Map<int, List<Track>> _cachedPlaylistTracks = {};
  bool _isCacheLoaded = false;

  Database get db => _db;
  String get appDataPath => _appDataPath;

  Future<String> _getAppDataPath() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      return '$home/Library/Application Support/Lyre';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      return '$appData/Lyre';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/Lyre';
    }
  }

  Future<void> init() async {
    _appDataPath = await _getAppDataPath();
    final audioDir = Directory(p.join(_appDataPath, 'audio'));
    final coverDir = Directory(p.join(_appDataPath, 'cover'));
    if (!await audioDir.exists()) await audioDir.create(recursive: true);
    if (!await coverDir.exists()) await coverDir.create(recursive: true);

    final DatabaseFactory factory;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactory;
    }

    final dbPath = p.join(_appDataPath, 'data.db');
    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS playlist_ids (
                playlist_id INTEGER PRIMARY KEY
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS playlists (
                playlist_id INTEGER PRIMARY KEY,
                title       TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tracks (
                track_id   INTEGER PRIMARY KEY,
                title      TEXT,
                artist     TEXT,
                duration   TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS playlist_tracks (
                playlist_id INTEGER,
                order_index INTEGER,
                track_id    INTEGER,
                PRIMARY KEY (playlist_id, track_id)
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS listening_history (
                history_id INTEGER PRIMARY KEY AUTOINCREMENT,
                track_id   INTEGER,
                title      TEXT,
                artist     TEXT,
                duration   TEXT,
                timestamp  TEXT,
                synced     INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS local_stats (
                user_id              INTEGER PRIMARY KEY,
                month_year           TEXT,
                total_minutes        INTEGER,
                total_plays          INTEGER,
                daily_avg_minutes    INTEGER,
                percentile_text      TEXT,
                top_tracks_json      TEXT,
                top_artists_json     TEXT,
                top_percentages_json TEXT,
                theme_color          TEXT,
                new_release          INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id            INTEGER PRIMARY KEY,
                username      TEXT UNIQUE,
                hidden_access INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sync_queue (
                key   TEXT PRIMARY KEY,
                value TEXT
            )
          ''');
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_listening_history_ts ON listening_history(timestamp)
          ''');
        },
        onOpen: (db) async {
          try {
            await db.execute('PRAGMA journal_mode = WAL;');
            await db.execute('PRAGMA busy_timeout = 5000;');
          } catch (_) {}
        },
      ),
    );
    ListeningStatsService.instance.setDatabase(_db);
    await loadAllIntoMemory();
  }

  Future<void> loadAllIntoMemory() async {
    try {
      final pResult = await _db.query('playlists');
      final playlists = pResult.map((row) => Playlist(
        playlistID: row['playlist_id'] as int,
        title: row['title'] as String,
      )).toList();

      final tResult = await _db.query('tracks');
      final tracks = tResult.map((row) => Track(
        trackID: row['track_id'] as int,
        title: row['title'] as String,
        artist: row['artist'] as String,
        duration: row['duration'] as String,
        downloaded: true,
        contributor: '',
      )).toList();

      final tracksById = <int, Track>{
        for (var t in tracks) t.trackID: t,
      };

      final ptResult = await _db.query('playlist_tracks', orderBy: 'playlist_id ASC, order_index ASC');
      final playlistTracks = <int, List<Track>>{};
      for (var row in ptResult) {
        final pid = row['playlist_id'] as int;
        final tid = row['track_id'] as int;
        final track = tracksById[tid];
        if (track != null) {
          playlistTracks.putIfAbsent(pid, () => []).add(track);
        }
      }

      _cachedPlaylists = playlists;
      _cachedAllTracks = tracks;
      _cachedPlaylistTracks = playlistTracks;
      _isCacheLoaded = true;
    } catch (e) {
      debugPrint('Error preloading playlists and tracks into memory: $e');
    }
  }

  String _normalizeString(String s) {
    if (s.isEmpty) return '';
    var str = s.toLowerCase();
    const withCombining = 'àáâãäåèéêëìíîïòóôõöùúûüýÿñç';
    const withoutCombining = 'aaaaaaeeeeiiiiooooouuuuyync';
    for (int i = 0; i < withCombining.length; i++) {
      str = str.replaceAll(withCombining[i], withoutCombining[i]);
    }
    str = str.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return str.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);
    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      v0 = List<int>.from(v1);
    }
    return v0[s2.length];
  }

  (bool, double) _isFuzzyMatch(String word1, String word2) {
    if (word1 == word2) return (true, 1.0);
    int l1 = word1.length;
    int l2 = word2.length;
    if (l1 == 0 || l2 == 0) return (false, 0.0);
    int maxLen = l1 > l2 ? l1 : l2;
    int dist = _levenshteinDistance(word1, word2);

    int maxAllowed = 0;
    if (maxLen >= 8) {
      maxAllowed = 2;
    } else if (maxLen >= 4) {
      maxAllowed = 1;
    }

    if (dist <= maxAllowed) {
      double sim = 1.0 - (dist / maxLen.toDouble());
      return (true, sim);
    }
    return (false, 0.0);
  }

  int _scoreSearchCandidate(String title, String artist, String query) {
    final normTitle = _normalizeString(title);
    final normArtist = _normalizeString(artist);
    final normQuery = _normalizeString(query);

    if (normQuery.isEmpty) return 0;

    if (normTitle == normQuery) return 100;
    if (normArtist == normQuery) return 90;

    if (normTitle.startsWith(normQuery)) return 85;
    if (normArtist.startsWith(normQuery)) return 75;

    if (normTitle.contains(normQuery)) return 65;
    if (normArtist.contains(normQuery)) return 55;

    final qWords = normQuery.split(' ');
    final tWords = normTitle.split(' ');
    final aWords = normArtist.split(' ');

    int matchedQTokens = 0;
    double fuzzyTokenScore = 0.0;

    for (final qw in qWords) {
      bool matched = false;
      for (final tw in tWords) {
        if (tw == qw || tw.startsWith(qw)) {
          matched = true;
          fuzzyTokenScore += 1.0;
          break;
        }
        final (isFuzz, sim) = _isFuzzyMatch(qw, tw);
        if (isFuzz) {
          matched = true;
          fuzzyTokenScore += sim;
          break;
        }
      }

      if (!matched) {
        for (final aw in aWords) {
          if (aw == qw || aw.startsWith(qw)) {
            matched = true;
            fuzzyTokenScore += 0.8;
            break;
          }
          final (isFuzz, sim) = _isFuzzyMatch(qw, aw);
          if (isFuzz) {
            matched = true;
            fuzzyTokenScore += (sim * 0.8);
            break;
          }
        }
      }

      if (matched) matchedQTokens++;
    }

    if (matchedQTokens == 0) return 0;

    double ratio = matchedQTokens / qWords.length.toDouble();
    int tokenScore = (ratio * 35 + (fuzzyTokenScore / qWords.length.toDouble()) * 15).round();
    return tokenScore.clamp(1, 49);
  }

  Future<List<Track>> searchTracks(String filter) async {
    if (filter.trim().isEmpty) {
      return [];
    }

    if (!_isCacheLoaded) {
      await loadAllIntoMemory();
    }

    final scored = <({int score, Track track})>[];
    for (final track in _cachedAllTracks) {
      final score = _scoreSearchCandidate(track.title, track.artist, filter);
      if (score > 0) {
        scored.add((score: score, track: track));
      }
    }

    scored.sort((a, b) {
      int cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.track.title.toLowerCase().compareTo(b.track.title.toLowerCase());
    });

    return scored.map((item) => item.track).toList();
  }

  Future<List<Playlist>> loadPlaylists() async {
    if (!_isCacheLoaded) {
      await loadAllIntoMemory();
    }
    return List<Playlist>.from(_cachedPlaylists);
  }

  void bringPlaylistToFront(int playlistID) {
    final index = _cachedPlaylists.indexWhere((p) => p.playlistID == playlistID);
    if (index > 0) {
      final playlist = _cachedPlaylists.removeAt(index);
      _cachedPlaylists.insert(0, playlist);
      notifyPlaylistChanged();
    }
  }

  Future<List<Track>> loadPlaylistTracks(int playlistID) async {
    if (!_isCacheLoaded) {
      await loadAllIntoMemory();
    }
    return List<Track>.from(_cachedPlaylistTracks[playlistID] ?? []);
  }

  Future<void> addToPlaylist(int playlistId, int trackId) async {
    try {
      await _db.rawInsert(
        'INSERT OR IGNORE INTO playlist_tracks (playlist_id, order_index, track_id) VALUES (?, (SELECT COALESCE(MAX(order_index), 0) + 1 FROM playlist_tracks WHERE playlist_id = ?), ?)',
        [playlistId, playlistId, trackId]
      );
      await loadAllIntoMemory();
      await setPendingPlaylistPush(true);
      notifyPlaylistChanged();
    } catch (e) {
      debugPrint('Could not add track to playlist: $e');
    }
  }

  Future<void> removeFromPlaylist(int playlistId, int trackId) async {
    try {
      await _db.delete('playlist_tracks', where: 'playlist_id = ? AND track_id = ?', whereArgs: [playlistId, trackId]);
      await loadAllIntoMemory();
      await setPendingPlaylistPush(true);
      notifyPlaylistChanged();
    } catch (e) {
      debugPrint('Could not remove track from playlist: $e');
    }
  }

  Future<void> changeTrackOrder(int playlistId, int trackId, int newOrder) async {
    try {
      final currentTracks = await loadPlaylistTracks(playlistId);
      final trackIds = currentTracks.map((t) => t.trackID).toList();
      final currentIndex = trackIds.indexOf(trackId);
      if (currentIndex != -1) {
        trackIds.removeAt(currentIndex);
        final targetIndex = (newOrder - 1).clamp(0, trackIds.length);
        trackIds.insert(targetIndex, trackId);
      }
      await reorderPlaylistTracks(playlistId, trackIds);
    } catch (e) {
      debugPrint('Could not change track order: $e');
    }
  }

  Future<void> reorderPlaylistTracks(int playlistId, List<int> orderedTrackIds) async {
    try {
      await _db.transaction((txn) async {
        await txn.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [playlistId]);
        for (int i = 0; i < orderedTrackIds.length; i++) {
          await txn.insert('playlist_tracks', {
            'playlist_id': playlistId,
            'order_index': i + 1,
            'track_id': orderedTrackIds[i],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      await loadAllIntoMemory();
      await setPendingPlaylistPush(true);
      notifyPlaylistChanged();
    } catch (e) {
      debugPrint('Could not reorder playlist tracks: $e');
    }
  }

  Future<bool> isInPlaylist(int playlistId, int trackId) async {
    if (!_isCacheLoaded) {
      await loadAllIntoMemory();
    }
    final tracks = _cachedPlaylistTracks[playlistId];
    if (tracks == null) return false;
    return tracks.any((t) => t.trackID == trackId);
  }

  Future<void> createPlaylist() async {
    final random = Random();
    final title = "New Playlist";
    
    int newPlaylistId;
    while (true) {
      newPlaylistId = 10000 + random.nextInt(90000);
      final result = await _db.query('playlists', where: 'playlist_id = ?', whereArgs: [newPlaylistId]);
      if (result.isEmpty) break;
    }

    try {
      await _db.insert('playlists', {
        'playlist_id': newPlaylistId,
        'title': title
      });
      
      await _db.insert('playlist_ids', {
        'playlist_id': newPlaylistId
      });
      await loadAllIntoMemory();
      await setPendingPlaylistPush(true);
      notifyPlaylistChanged();
    } catch (e) {
      debugPrint('Could not create playlist: $e');
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    try {
      await _db.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [playlistId]);
      await _db.delete('playlists', where: 'playlist_id = ?', whereArgs: [playlistId]);
      await _db.delete('playlist_ids', where: 'playlist_id = ?', whereArgs: [playlistId]);
      await loadAllIntoMemory();
      await setPendingPlaylistPush(true);
      notifyPlaylistChanged();
    } catch (e) {
      debugPrint('Could not delete playlist: $e');
    }
  }

  Future<void> editPlaylistTitle(int playlistId, String newTitle) async {
    try {
      await _db.update('playlists', {'title': newTitle}, where: 'playlist_id = ?', whereArgs: [playlistId]);
      await loadAllIntoMemory();
      await setPendingPlaylistPush(true);
      notifyPlaylistChanged();
    } catch (e) {
      debugPrint('Could not edit playlist title: $e');
    }
  }

  Future<void> newTrack(Track track, {bool reloadCache = true}) async {
    try {
      await _db.insert(
        'tracks',
        {
          'track_id': track.trackID,
          'title': track.title,
          'artist': track.artist,
          'duration': track.duration,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (reloadCache) await loadAllIntoMemory();
    } catch (e) {
      debugPrint('Could not add track: $e');
    }
  }

  Future<void> deleteTrack(Track track) async {
    try {
      await _db.delete('playlist_tracks', where: 'track_id = ?', whereArgs: [track.trackID]);
      await _db.delete('tracks', where: 'track_id = ?', whereArgs: [track.trackID]);
      await loadAllIntoMemory();
    } catch (e) {
      debugPrint('Could not delete track: $e');
    }
  }

  Future<List<Track>> getAllTracks() async {
    if (!_isCacheLoaded) {
      await loadAllIntoMemory();
    }
    return List<Track>.from(_cachedAllTracks);
  }

  Future<List<Track>> getUnusedDownloadedTracks() async {
    if (!_isCacheLoaded) {
      await loadAllIntoMemory();
    }
    final result = await _db.rawQuery('''
      SELECT t.track_id, t.title, t.artist, t.duration 
      FROM tracks t 
      WHERE t.track_id NOT IN (SELECT DISTINCT track_id FROM playlist_tracks)
    ''');
    return result.map((row) => Track(
      trackID: row['track_id'] as int,
      title: row['title'] as String,
      artist: row['artist'] as String,
      duration: row['duration'] as String,
      downloaded: true,
      contributor: '',
    )).toList();
  }

  Future<bool> syncLocalPlaylists(List<dynamic> serverPlaylists) async {
    try {
      final localPlaylists = await loadPlaylists();
      final localMap = {for (var p in localPlaylists) p.playlistID: p};
      final serverMap = <int, Map<String, dynamic>>{};

      await _db.transaction((txn) async {
        for (var sp in serverPlaylists) {
          final pid = sp['playlist_id'] as int;
          final name = (sp['name'] as String?) ?? 'Playlist $pid';
          final trackIds = (sp['tracks'] as List<dynamic>? ?? []).map((e) => e as int).toList();
          serverMap[pid] = {'name': name, 'tracks': trackIds};

          if (!localMap.containsKey(pid)) {
            await txn.insert('playlists', {'playlist_id': pid, 'title': name}, conflictAlgorithm: ConflictAlgorithm.replace);
            await txn.insert('playlist_ids', {'playlist_id': pid}, conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            await txn.update('playlists', {'title': name}, where: 'playlist_id = ?', whereArgs: [pid]);
          }

          // Clear and re-insert tracks for this playlist in sequence
          await txn.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [pid]);
          for (int i = 0; i < trackIds.length; i++) {
            await txn.insert('playlist_tracks', {
              'playlist_id': pid,
              'order_index': i + 1,
              'track_id': trackIds[i],
            });
          }
        }
      });

      // Check if there are any local playlists not yet on the server
      bool hasUnsyncedLocal = false;
      for (var local in localPlaylists) {
        if (!serverMap.containsKey(local.playlistID)) {
          hasUnsyncedLocal = true;
          break;
        }
      }

      await loadAllIntoMemory();

      return hasUnsyncedLocal;
    } catch (e) {
      debugPrint('Error syncing local playlists: $e');
      return false;
    }
  }

  Future<void> clearAllLocalData() async {
    try {
      // 1. Clear database tables
      await _db.delete('playlist_tracks');
      await _db.delete('playlists');
      await _db.delete('playlist_ids');
      await _db.delete('tracks');
      await _db.delete('listening_history');
      await _db.delete('local_stats');
      await _db.delete('sync_queue');

      // 2. Clear all downloaded audio files
      final audioDir = Directory(p.join(_appDataPath, 'audio'));
      if (await audioDir.exists()) {
        final files = await audioDir.list().toList();
        for (var file in files) {
          try {
            await file.delete(recursive: true);
          } catch (_) {}
        }
      }

      // 3. Clear all cover image files
      final coverDir = Directory(p.join(_appDataPath, 'cover'));
      if (await coverDir.exists()) {
        final files = await coverDir.list().toList();
        for (var file in files) {
          try {
            await file.delete(recursive: true);
          } catch (_) {}
        }
      }

      await loadAllIntoMemory();
    } catch (e) {
      debugPrint('Error clearing all local data: $e');
    }
  }

  Future<void> setPendingPlaylistPush(bool pending) async {
    try {
      await _db.insert(
        'sync_queue',
        {'key': 'pending_playlist_push', 'value': pending ? '1' : '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error setting pending playlist push: $e');
    }
  }

  Future<bool> hasPendingPlaylistPush() async {
    try {
      final rows = await _db.query('sync_queue', where: 'key = ?', whereArgs: ['pending_playlist_push']);
      if (rows.isNotEmpty) {
        return rows.first['value'] == '1';
      }
    } catch (e) {
      debugPrint('Error checking pending playlist push: $e');
    }
    return false;
  }

  Future<void> addPendingDownload(int trackId) async {
    try {
      await _db.insert('sync_queue', {'key': 'dl_$trackId', 'value': '$trackId'}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<void> addPendingRemoveDownload(int trackId) async {
    try {
      await _db.insert('sync_queue', {'key': 'rm_dl_$trackId', 'value': '$trackId'}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<List<int>> getPendingDownloads() async {
    try {
      final rows = await _db.query('sync_queue', where: "key LIKE 'dl_%'");
      return rows.map((r) => int.parse(r['value'] as String)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<int>> getPendingRemoveDownloads() async {
    try {
      final rows = await _db.query('sync_queue', where: "key LIKE 'rm_dl_%'");
      return rows.map((r) => int.parse(r['value'] as String)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearPendingDownload(int trackId) async {
    try {
      await _db.delete('sync_queue', where: 'key = ?', whereArgs: ['dl_$trackId']);
    } catch (_) {}
  }

  Future<void> clearPendingRemoveDownload(int trackId) async {
    try {
      await _db.delete('sync_queue', where: 'key = ?', whereArgs: ['rm_dl_$trackId']);
    } catch (_) {}
  }

  Future<void> clearAllPendingDownloads() async {
    try {
      await _db.delete('sync_queue', where: "key LIKE 'dl_%'");
    } catch (_) {}
  }

  Future<void> clearAllPendingRemoveDownloads() async {
    try {
      await _db.delete('sync_queue', where: "key LIKE 'rm_dl_%'");
    } catch (_) {}
  }
}
