import 'dart:io';
import 'package:sqflite/sqflite.dart';
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

  String get appDataPath => _appDataPath;

  Future<String> _getAppDataPath() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      return '$home/Library/Application Support/Napster';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      return '$appData/Napster';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/Napster';
    }
  }

  Future<void> init() async {
    _appDataPath = await _getAppDataPath();
    final audioDir = Directory(p.join(_appDataPath, 'audio'));
    final coverDir = Directory(p.join(_appDataPath, 'cover'));
    if (!await audioDir.exists()) await audioDir.create(recursive: true);
    if (!await coverDir.exists()) await coverDir.create(recursive: true);

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = p.join(_appDataPath, 'data.db');
    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS PlaylistIDs (
                playlist_id INTEGER PRIMARY KEY
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS Playlists (
                playlist_id INTEGER PRIMARY KEY,
                title       TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS Tracks (
                track_id   INTEGER PRIMARY KEY,
                title      TEXT,
                artist     TEXT,
                duration   TEXT
            )
          ''');
        },
      ),
    );
    ListeningStatsService.instance.setDatabase(_db);
  }

  Future<List<Track>> searchTracks(String filter) async {
    final normalizedFilter = filter.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
    if (normalizedFilter.isEmpty) {
      return [];
    }

    // Since we do Dart-side normalization for the search text, 
    // we use standard LIKE to match as closely as possible to the Java implementation
    final result = await _db.rawQuery(
      'SELECT * FROM Tracks WHERE LOWER(title) LIKE ? OR LOWER(artist) LIKE ? ORDER BY title ASC',
      ['%$normalizedFilter%', '%$normalizedFilter%']
    );

    return result.map((row) => Track(
      trackID: row['track_id'] as int,
      title: row['title'] as String,
      artist: row['artist'] as String,
      duration: row['duration'] as String,
      downloaded: true,
      contributor: '',
    )).toList();
  }

  Future<List<Playlist>> loadPlaylists() async {
    final result = await _db.query('Playlists');
    return result.map((row) => Playlist(
      playlistID: row['playlist_id'] as int,
      title: row['title'] as String,
    )).toList();
  }

  Future<List<Track>> loadPlaylistTracks(int playlistID) async {
    final tableName = 'playlist_$playlistID';
    List<Map<String, dynamic>> idResults;
    try {
      idResults = await _db.rawQuery('SELECT * FROM $tableName ORDER BY [order] ASC');
    } catch (e) {
      print('Could not load playlist track IDs: $e');
      return [];
    }

    List<Track> tracks = [];
    for (var row in idResults) {
      final trackId = row['track_id'] as int;
      final trackResults = await _db.query('Tracks', where: 'track_id = ?', whereArgs: [trackId]);
      for (var tRow in trackResults) {
        tracks.add(Track(
          trackID: tRow['track_id'] as int,
          title: tRow['title'] as String,
          artist: tRow['artist'] as String,
          duration: tRow['duration'] as String,
          downloaded: true,
          contributor: '',
        ));
      }
    }
    return tracks;
  }

  Future<void> addToPlaylist(int playlistId, int trackId) async {
    final tableName = 'playlist_$playlistId';
    try {
      await _db.rawInsert(
        'INSERT INTO $tableName ([order], track_id) VALUES ((SELECT COALESCE(MAX([order]), 0) + 1 FROM $tableName), ?)',
        [trackId]
      );
    } catch (e) {
      print('Could not add track to playlist: $e');
    }
  }

  Future<void> removeFromPlaylist(int playlistId, int trackId) async {
    final tableName = 'playlist_$playlistId';
    try {
      await _db.delete(tableName, where: 'track_id = ?', whereArgs: [trackId]);
    } catch (e) {
      print('Could not remove track from playlist: $e');
    }
  }

  Future<void> changeTrackOrder(int playlistId, int trackId, int newOrder) async {
    final tableName = 'playlist_$playlistId';
    try {
      await _db.update(tableName, {'order': newOrder}, where: 'track_id = ?', whereArgs: [trackId]);
    } catch (e) {
      print('Could not change track order: $e');
    }
  }

  Future<bool> isInPlaylist(int playlistId, int trackId) async {
    final tableName = 'playlist_$playlistId';
    try {
      final result = await _db.query(tableName, where: 'track_id = ?', whereArgs: [trackId], limit: 1);
      return result.isNotEmpty;
    } catch (e) {
      print('Could not check playlist contents: $e');
      return false;
    }
  }

  Future<void> createPlaylist() async {
    final random = Random();
    final title = "New Playlist";
    
    int newPlaylistId;
    while (true) {
      newPlaylistId = 10000 + random.nextInt(90000);
      final result = await _db.query('Playlists', where: 'playlist_id = ?', whereArgs: [newPlaylistId]);
      if (result.isEmpty) break;
    }

    final tableName = 'playlist_$newPlaylistId';
    try {
      await _db.execute('''
        CREATE TABLE $tableName (
            [order] INTEGER,
            track_id INTEGER
        )
      ''');
      
      await _db.insert('Playlists', {
        'playlist_id': newPlaylistId,
        'title': title
      });
      
      await _db.insert('PlaylistIDs', {
        'playlist_id': newPlaylistId
      });
    } catch (e) {
      print('Could not create playlist: $e');
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    final tableName = 'playlist_$playlistId';
    try {
      await _db.execute('DROP TABLE IF EXISTS $tableName');
      await _db.delete('Playlists', where: 'playlist_id = ?', whereArgs: [playlistId]);
      await _db.delete('PlaylistIDs', where: 'playlist_id = ?', whereArgs: [playlistId]);
    } catch (e) {
      print('Could not delete playlist: $e');
    }
  }

  Future<void> editPlaylistTitle(int playlistId, String newTitle) async {
    try {
      await _db.update('Playlists', {'title': newTitle}, where: 'playlist_id = ?', whereArgs: [playlistId]);
    } catch (e) {
      print('Could not edit playlist title: $e');
    }
  }

  Future<void> newTrack(Track track) async {
    try {
      await _db.insert(
        'Tracks',
        {
          'track_id': track.trackID,
          'title': track.title,
          'artist': track.artist,
          'duration': track.duration,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      print('Could not add track: $e');
    }
  }

  Future<void> deleteTrack(Track track) async {
    try {
      final playlists = await _db.query('Playlists', columns: ['playlist_id']);
      for (var row in playlists) {
        await removeFromPlaylist(row['playlist_id'] as int, track.trackID);
      }
      await _db.delete('Tracks', where: 'track_id = ?', whereArgs: [track.trackID]);
    } catch (e) {
      print('Could not delete track: $e');
    }
  }

  Future<List<Track>> getAllTracks() async {
    try {
      final result = await _db.query('Tracks');
      return result.map((row) => Track(
        trackID: row['track_id'] as int,
        title: row['title'] as String,
        artist: row['artist'] as String,
        duration: row['duration'] as String,
        downloaded: true,
        contributor: '',
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> syncLocalPlaylists(List<dynamic> serverPlaylists) async {
    try {
      final localPlaylists = await loadPlaylists();
      final localMap = {for (var p in localPlaylists) p.playlistID: p};
      final serverMap = <int, Map<String, dynamic>>{};

      for (var sp in serverPlaylists) {
        final pid = sp['playlist_id'] as int;
        final name = (sp['name'] as String?) ?? 'Playlist $pid';
        final trackIds = (sp['tracks'] as List<dynamic>? ?? []).map((e) => e as int).toList();
        serverMap[pid] = {'name': name, 'tracks': trackIds};

        final tableName = 'playlist_$pid';
        // Create table if not exists
        await _db.execute('''
          CREATE TABLE IF NOT EXISTS $tableName (
              [order] INTEGER,
              track_id INTEGER
          )
        ''');

        if (!localMap.containsKey(pid)) {
          await _db.insert('Playlists', {'playlist_id': pid, 'title': name}, conflictAlgorithm: ConflictAlgorithm.replace);
          await _db.insert('PlaylistIDs', {'playlist_id': pid}, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await _db.update('Playlists', {'title': name}, where: 'playlist_id = ?', whereArgs: [pid]);
        }

        // Clear and re-insert tracks in sequence
        await _db.delete(tableName);
        for (int i = 0; i < trackIds.length; i++) {
          await _db.insert(tableName, {
            'order': i + 1,
            'track_id': trackIds[i],
          });
        }
      }

      // Delete any local playlist not on server
      for (var local in localPlaylists) {
        if (!serverMap.containsKey(local.playlistID)) {
          await deletePlaylist(local.playlistID);
        }
      }
    } catch (e) {
      print('Error syncing local playlists: $e');
    }
  }

  Future<void> clearAllLocalData() async {
    try {
      // 1. Drop all custom playlist tables
      final playlists = await _db.query('Playlists', columns: ['playlist_id']);
      for (var row in playlists) {
        final pid = row['playlist_id'] as int;
        await _db.execute('DROP TABLE IF EXISTS playlist_$pid');
      }

      // 2. Clear core SQLite tables
      await _db.delete('Playlists');
      await _db.delete('PlaylistIDs');
      await _db.delete('Tracks');

      // 3. Clear all downloaded audio files
      final audioDir = Directory(p.join(_appDataPath, 'audio'));
      if (await audioDir.exists()) {
        final files = audioDir.listSync();
        for (var file in files) {
          try {
            await file.delete(recursive: true);
          } catch (_) {}
        }
      }

      // 4. Clear all cover image files
      final coverDir = Directory(p.join(_appDataPath, 'cover'));
      if (await coverDir.exists()) {
        final files = coverDir.listSync();
        for (var file in files) {
          try {
            await file.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (e) {
      print('Error clearing all local data: $e');
    }
  }
}

