import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
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
        version: 2,
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
                duration   TEXT,
                downloaded INTEGER DEFAULT 0
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
                theme_color          TEXT
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
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE tracks ADD COLUMN downloaded INTEGER DEFAULT 0');
          }
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

  Future<void> _saveLocalPlaylistOrder(List<int> playlistIds) async {
    try {
      await _db.insert(
        'sync_queue',
        {'key': 'local_playlist_order', 'value': jsonEncode(playlistIds)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving local playlist order: $e');
    }
  }

  Future<List<int>> _getLocalPlaylistOrder() async {
    try {
      final rows = await _db.query('sync_queue', where: 'key = ?', whereArgs: ['local_playlist_order']);
      if (rows.isNotEmpty) {
        final val = rows.first['value'] as String?;
        if (val != null) {
          final List<dynamic> parsed = jsonDecode(val);
          return parsed.map((e) => e as int).toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading local playlist order: $e');
    }
    return [];
  }

  Future<void> loadAllIntoMemory() async {
    try {
      final pResult = await _db.query('playlists');
      final dbPlaylists = pResult.map((row) => Playlist(
        playlistID: row['playlist_id'] as int,
        title: row['title'] as String,
      )).toList();

      final dbMap = {for (var p in dbPlaylists) p.playlistID: p};
      final storedOrder = await _getLocalPlaylistOrder();
      final referenceOrder = _cachedPlaylists.isNotEmpty
          ? _cachedPlaylists.map((p) => p.playlistID).toList()
          : storedOrder;

      final List<Playlist> orderedPlaylists = [];
      for (var pid in referenceOrder) {
        if (dbMap.containsKey(pid)) {
          orderedPlaylists.add(dbMap.remove(pid)!);
        }
      }
      orderedPlaylists.addAll(dbMap.values);

      final tResult = await _db.query('tracks');
      final tracks = tResult.map((row) => Track(
        trackID: row['track_id'] as int,
        title: row['title'] as String,
        artist: row['artist'] as String,
        duration: row['duration'] as String,
        downloaded: (row['downloaded'] as int? ?? 0) == 1,
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
        } else {
          playlistTracks.putIfAbsent(pid, () => []).add(Track(
            trackID: tid,
            title: 'Track $tid',
            artist: 'Unknown',
            duration: '0:00',
            downloaded: false,
            contributor: '',
          ));
        }
      }

      _cachedPlaylists = orderedPlaylists;
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

  Future<void> bringPlaylistToFront(int playlistID) async {
    final index = _cachedPlaylists.indexWhere((p) => p.playlistID == playlistID);
    if (index > 0) {
      final playlist = _cachedPlaylists.removeAt(index);
      _cachedPlaylists.insert(0, playlist);
      await _saveLocalPlaylistOrder(_cachedPlaylists.map((p) => p.playlistID).toList());
      await setPendingPlaylistPush(true);
      notifyPlaylistChanged();
    }
  }

  Future<void> reorderPlaylists(List<int> orderedPlaylistIds) async {
    try {
      final map = {for (var p in _cachedPlaylists) p.playlistID: p};
      final List<Playlist> reordered = [];
      for (var id in orderedPlaylistIds) {
        if (map.containsKey(id)) {
          reordered.add(map.remove(id)!);
        }
      }
      reordered.addAll(map.values);
      _cachedPlaylists = reordered;
      await _saveLocalPlaylistOrder(_cachedPlaylists.map((p) => p.playlistID).toList());
      await setPendingPlaylistPush(true);
      notifyPlaylistChanged();
    } catch (e) {
      debugPrint('Could not reorder playlists: $e');
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
      await _saveLocalPlaylistOrder(_cachedPlaylists.map((p) => p.playlistID).toList());
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
      await _saveLocalPlaylistOrder(_cachedPlaylists.map((p) => p.playlistID).toList());
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

  Future<void> newTrack(Track track, {bool reloadCache = true, bool downloaded = false}) async {
    try {
      await _db.insert(
        'tracks',
        {
          'track_id': track.trackID,
          'title': track.title,
          'artist': track.artist,
          'duration': track.duration,
          'downloaded': downloaded ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (reloadCache) await loadAllIntoMemory();
    } catch (e) {
      debugPrint('Could not add track: $e');
    }
  }

  /// Inserts or updates track metadata without changing download state for existing tracks.
  Future<void> upsertTrackMetadata(Track track) async {
    try {
      final existing = await _db.query('tracks', where: 'track_id = ?', whereArgs: [track.trackID]);
      if (existing.isEmpty) {
        await _db.insert('tracks', {
          'track_id': track.trackID,
          'title': track.title,
          'artist': track.artist,
          'duration': track.duration,
          'downloaded': 0,
        });
      } else {
        await _db.update('tracks', {
          'title': track.title,
          'artist': track.artist,
          'duration': track.duration,
        }, where: 'track_id = ?', whereArgs: [track.trackID]);
      }
    } catch (e) {
      debugPrint('Could not upsert track metadata: $e');
    }
  }

  bool isTrackDownloaded(int trackId) {
    if (_isCacheLoaded) {
      final matches = _cachedAllTracks.where((t) => t.trackID == trackId);
      if (matches.isNotEmpty) {
        if (!matches.first.downloaded) return false;
      } else {
        return false;
      }
    }
    final flac = File(p.join(_appDataPath, 'audio', '$trackId.flac'));
    if (flac.existsSync() && flac.lengthSync() > 0) return true;
    return false;
  }

  Future<void> markTrackDownloaded(int trackId) async {
    try {
      await _db.update('tracks', {'downloaded': 1}, where: 'track_id = ?', whereArgs: [trackId]);
      await loadAllIntoMemory();
      notifyPlaylistChanged();
    } catch (e) {
      debugPrint('Could not mark track as downloaded: $e');
    }
  }

  Future<List<Track>> getUndownloadedTracks() async {
    try {
      final result = await _db.query('tracks', where: 'downloaded = 0');
      return result.map((row) => Track(
        trackID: row['track_id'] as int,
        title: row['title'] as String? ?? '',
        artist: row['artist'] as String? ?? '',
        duration: row['duration'] as String? ?? '',
        downloaded: false,
        contributor: '',
      )).toList();
    } catch (e) {
      debugPrint('Could not get undownloaded tracks: $e');
      return [];
    }
  }

  Future<void> resetTrackDownloadState(int trackId) async {
    try {
      await _db.update('tracks', {'downloaded': 0}, where: 'track_id = ?', whereArgs: [trackId]);
      await loadAllIntoMemory();
    } catch (e) {
      debugPrint('Could not reset track download state: $e');
    }
  }

  /// Scans local tracks for missing metadata (e.g. "Track {id}" placeholders) or corrupted/missing audio files.
  Future<({List<Track> metadataBroken, List<Track> downloadBroken})> getBrokenTracks() async {
    final metadataBroken = <Track>[];
    final downloadBroken = <Track>[];
    try {
      final allTracks = await getAllTracks();
      for (final track in allTracks) {
        final isPlaceholder = track.title.trim() == 'Track ${track.trackID}' ||
            track.title.trim().isEmpty ||
            track.artist.trim() == 'Unknown' ||
            track.artist.trim().isEmpty;
        if (isPlaceholder) {
          metadataBroken.add(track);
        }

        if (track.downloaded) {
          final flacFile = File(p.join(_appDataPath, 'audio', '${track.trackID}.flac'));
          bool hasAudio = false;
          if (await flacFile.exists()) {
            final len = await flacFile.length();
            if (len > 0) hasAudio = true;
          }
          if (!hasAudio) {
            downloadBroken.add(track);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning for broken tracks: $e');
    }
    return (metadataBroken: metadataBroken, downloadBroken: downloadBroken);
  }

  /// Removes tracks from the local DB and disk that are not in the given set of track IDs.
  Future<List<Track>> removeTracksNotIn(Set<int> keepTrackIds) async {
    try {
      final allTracks = await getAllTracks();
      final toRemove = allTracks.where((t) => !keepTrackIds.contains(t.trackID)).toList();
      for (final track in toRemove) {
        await _db.delete('playlist_tracks', where: 'track_id = ?', whereArgs: [track.trackID]);
        await _db.delete('tracks', where: 'track_id = ?', whereArgs: [track.trackID]);
        // Delete audio and cover files
        final audioFlac = File(p.join(_appDataPath, 'audio', '${track.trackID}.flac'));
        final cover = File(p.join(_appDataPath, 'cover', '${track.trackID}.jpg'));
        if (await audioFlac.exists()) await audioFlac.delete();
        if (await cover.exists()) await cover.delete();
      }
      return toRemove;
    } catch (e) {
      debugPrint('Could not remove stale tracks: $e');
      return [];
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

  Future<void> purgeTrackReferences(int trackID) async {
    try {
      // 1. Delete from database tables
      await _db.delete('playlist_tracks', where: 'track_id = ?', whereArgs: [trackID]);
      await _db.delete('tracks', where: 'track_id = ?', whereArgs: [trackID]);
      await _db.delete('listening_history', where: 'track_id = ?', whereArgs: [trackID]);
      
      // Clean up sync queue if pending download or removal was queued
      try {
        final pendingDownloads = await getPendingDownloads();
        if (pendingDownloads.contains(trackID)) {
          await clearPendingDownload(trackID);
        }
        final pendingRemoves = await getPendingRemoveDownloads();
        if (pendingRemoves.contains(trackID)) {
          await clearPendingRemoveDownload(trackID);
        }
      } catch (_) {}

      // 2. Delete local files
      final flacFile = File(p.join(_appDataPath, 'audio', '$trackID.flac'));
      final coverFile = File(p.join(_appDataPath, 'cover', '$trackID.jpg'));

      try {
        PaintingBinding.instance.imageCache.evict(FileImage(coverFile));
        if (await flacFile.exists()) await flacFile.delete();
        if (await coverFile.exists()) await coverFile.delete();
      } catch (e) {
        debugPrint('Error deleting local asset files during purge: $e');
      }

      await loadAllIntoMemory();
    } catch (e) {
      debugPrint('Could not purge track references: $e');
    }
  }

  Future<void> updateTrackMetadata(int trackID, String title, String artist, String duration) async {
    try {
      await _db.update(
        'tracks',
        {
          'title': title,
          'artist': artist,
          'duration': duration,
        },
        where: 'track_id = ?',
        whereArgs: [trackID],
      );
      await _db.update(
        'listening_history',
        {
          'title': title,
          'artist': artist,
          'duration': duration,
        },
        where: 'track_id = ?',
        whereArgs: [trackID],
      );
      await loadAllIntoMemory();
    } catch (e) {
      debugPrint('Could not update track metadata: $e');
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
      WHERE t.track_id NOT IN (SELECT DISTINCT track_id FROM playlist_tracks) AND t.downloaded = 1
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
      final List<Playlist> syncedOrder = [];

      await _db.transaction((txn) async {
        for (var sp in serverPlaylists) {
          final pid = sp['playlist_id'] as int;
          final name = (sp['name'] as String?) ?? 'Playlist $pid';
          final trackIds = (sp['tracks'] as List<dynamic>? ?? []).map((e) => e as int).toList();
          serverMap[pid] = {'name': name, 'tracks': trackIds};
          syncedOrder.add(Playlist(playlistID: pid, title: name));

          if (!localMap.containsKey(pid)) {
            await txn.insert('playlists', {'playlist_id': pid, 'title': name}, conflictAlgorithm: ConflictAlgorithm.replace);
            await txn.insert('playlist_ids', {'playlist_id': pid}, conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            await txn.update('playlists', {'title': name}, where: 'playlist_id = ?', whereArgs: [pid]);
          }

          // Clear and re-insert tracks for this playlist in sequence
          await txn.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [pid]);
          for (int i = 0; i < trackIds.length; i++) {
            final tid = trackIds[i];
            await txn.rawInsert('''
              INSERT OR IGNORE INTO tracks (track_id, title, artist, duration, downloaded)
              VALUES (?, ?, ?, ?, 0)
            ''', [tid, 'Track $tid', 'Unknown', '0:00']);
            await txn.insert('playlist_tracks', {
              'playlist_id': pid,
              'order_index': i + 1,
              'track_id': tid,
            });
          }
        }
      });

      _cachedPlaylists = syncedOrder;
      await _saveLocalPlaylistOrder(_cachedPlaylists.map((p) => p.playlistID).toList());
      await loadAllIntoMemory();

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
