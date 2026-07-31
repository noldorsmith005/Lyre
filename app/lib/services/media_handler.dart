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
                timestamp  TEXT
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
            CREATE TABLE IF NOT EXISTS sync_queue (
                key   TEXT PRIMARY KEY,
                value TEXT
            )
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

      final ptResult = await _db.query('playlist_tracks', orderBy: 'order_index ASC');
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
      print('Error preloading playlists and tracks into memory: $e');
    }
  }

  Future<List<Track>> searchTracks(String filter) async {
    final normalizedFilter = filter.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').toLowerCase().trim();
    if (normalizedFilter.isEmpty) {
      return [];
    }

    if (!_isCacheLoaded) {
      await loadAllIntoMemory();
    }

    return _cachedAllTracks.where((t) {
      final titleNorm = t.title.toLowerCase();
      final artistNorm = t.artist.toLowerCase();
      return titleNorm.contains(normalizedFilter) || artistNorm.contains(normalizedFilter);
    }).toList();
  }

  Future<List<Playlist>> loadPlaylists() async {
    if (!_isCacheLoaded) {
      await loadAllIntoMemory();
    }
    return List<Playlist>.from(_cachedPlaylists);
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
      onPlaylistChanged?.call();
    } catch (e) {
      print('Could not add track to playlist: $e');
    }
  }

  Future<void> removeFromPlaylist(int playlistId, int trackId) async {
    try {
      await _db.delete('playlist_tracks', where: 'playlist_id = ? AND track_id = ?', whereArgs: [playlistId, trackId]);
      await loadAllIntoMemory();
      await setPendingPlaylistPush(true);
      onPlaylistChanged?.call();
    } catch (e) {
      print('Could not remove track from playlist: $e');
    }
  }

  Future<void> changeTrackOrder(int playlistId, int trackId, int newOrder) async {
    try {
      await _db.update('playlist_tracks', {'order_index': newOrder}, where: 'playlist_id = ? AND track_id = ?', whereArgs: [playlistId, trackId]);
      await loadAllIntoMemory();
      await setPendingPlaylistPush(true);
      onPlaylistChanged?.call();
    } catch (e) {
      print('Could not change track order: $e');
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
      onPlaylistChanged?.call();
    } catch (e) {
      print('Could not create playlist: $e');
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    try {
      await _db.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [playlistId]);
      await _db.delete('playlists', where: 'playlist_id = ?', whereArgs: [playlistId]);
      await _db.delete('playlist_ids', where: 'playlist_id = ?', whereArgs: [playlistId]);
      await loadAllIntoMemory();
      await setPendingPlaylistPush(true);
      onPlaylistChanged?.call();
    } catch (e) {
      print('Could not delete playlist: $e');
    }
  }

  Future<void> editPlaylistTitle(int playlistId, String newTitle) async {
    try {
      await _db.update('playlists', {'title': newTitle}, where: 'playlist_id = ?', whereArgs: [playlistId]);
      await loadAllIntoMemory();
      await setPendingPlaylistPush(true);
      onPlaylistChanged?.call();
    } catch (e) {
      print('Could not edit playlist title: $e');
    }
  }

  Future<void> newTrack(Track track) async {
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
      await loadAllIntoMemory();
    } catch (e) {
      print('Could not add track: $e');
    }
  }

  Future<void> deleteTrack(Track track) async {
    try {
      await _db.delete('playlist_tracks', where: 'track_id = ?', whereArgs: [track.trackID]);
      await _db.delete('tracks', where: 'track_id = ?', whereArgs: [track.trackID]);
      await loadAllIntoMemory();
    } catch (e) {
      print('Could not delete track: $e');
    }
  }

  Future<List<Track>> getAllTracks() async {
    if (!_isCacheLoaded) {
      await loadAllIntoMemory();
    }
    return List<Track>.from(_cachedAllTracks);
  }

  Future<bool> syncLocalPlaylists(List<dynamic> serverPlaylists) async {
    try {
      final localPlaylists = await loadPlaylists();
      final localMap = {for (var p in localPlaylists) p.playlistID: p};
      final serverMap = <int, Map<String, dynamic>>{};

      for (var sp in serverPlaylists) {
        final pid = sp['playlist_id'] as int;
        final name = (sp['name'] as String?) ?? 'Playlist $pid';
        final trackIds = (sp['tracks'] as List<dynamic>? ?? []).map((e) => e as int).toList();
        serverMap[pid] = {'name': name, 'tracks': trackIds};

        if (!localMap.containsKey(pid)) {
          await _db.insert('playlists', {'playlist_id': pid, 'title': name}, conflictAlgorithm: ConflictAlgorithm.replace);
          await _db.insert('playlist_ids', {'playlist_id': pid}, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await _db.update('playlists', {'title': name}, where: 'playlist_id = ?', whereArgs: [pid]);
        }

        // Clear and re-insert tracks for this playlist in sequence
        await _db.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [pid]);
        for (int i = 0; i < trackIds.length; i++) {
          await _db.insert('playlist_tracks', {
            'playlist_id': pid,
            'order_index': i + 1,
            'track_id': trackIds[i],
          });
        }
      }

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
      print('Error syncing local playlists: $e');
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

      // 2. Clear all downloaded audio files
      final audioDir = Directory(p.join(_appDataPath, 'audio'));
      if (await audioDir.exists()) {
        final files = audioDir.listSync();
        for (var file in files) {
          try {
            await file.delete(recursive: true);
          } catch (_) {}
        }
      }

      // 3. Clear all cover image files
      final coverDir = Directory(p.join(_appDataPath, 'cover'));
      if (await coverDir.exists()) {
        final files = coverDir.listSync();
        for (var file in files) {
          try {
            await file.delete(recursive: true);
          } catch (_) {}
        }
      }

      await loadAllIntoMemory();
    } catch (e) {
      print('Error clearing all local data: $e');
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
      print('Error setting pending playlist push: $e');
    }
  }

  Future<bool> hasPendingPlaylistPush() async {
    try {
      final rows = await _db.query('sync_queue', where: 'key = ?', whereArgs: ['pending_playlist_push']);
      if (rows.isNotEmpty) {
        return rows.first['value'] == '1';
      }
    } catch (e) {
      print('Error checking pending playlist push: $e');
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
}
