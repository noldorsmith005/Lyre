import 'dart:math';
import '../models/track.dart';
import 'media_handler.dart';

enum VibeType {
  myCurrentFavs,
  beenAwhile,
  mixItUp,
}

extension VibeTypeExtension on VibeType {
  String get title {
    switch (this) {
      case VibeType.myCurrentFavs:
        return 'my current favs';
      case VibeType.beenAwhile:
        return 'been awhile';
      case VibeType.mixItUp:
        return 'mix it up';
    }
  }

  String get subtitle {
    switch (this) {
      case VibeType.myCurrentFavs:
        return 'Most played songs';
      case VibeType.beenAwhile:
        return 'Least played songs';
      case VibeType.mixItUp:
        return 'Mix of songs from up to 3 random playlists';
    }
  }

  String get description {
    switch (this) {
      case VibeType.myCurrentFavs:
        return 'Pulls 20 random songs from your most played tracks in the last week.';
      case VibeType.beenAwhile:
        return 'Pulls 20 random songs from your least played or forgotten tracks.';
      case VibeType.mixItUp:
        return 'Pulls 20 random songs sampled from up to 3 random playlists.';
    }
  }
}

class VibeQueueService {
  static Future<List<Track>> generateQueue({
    required VibeType vibe,
    required MediaHandler mediaHandler,
    int count = 20,
  }) async {
    final db = mediaHandler.db;
    final allTracks = await mediaHandler.getAllTracks();
    if (allTracks.isEmpty) return [];

    List<Track> selectedTracks = [];

    switch (vibe) {
      case VibeType.myCurrentFavs:
        selectedTracks = await _getMostPlayedTracks(db, mediaHandler);
        break;
      case VibeType.beenAwhile:
        selectedTracks = await _getLeastPlayedTracks(db, mediaHandler);
        break;
      case VibeType.mixItUp:
        selectedTracks = await _getMixItUpTracks(db, mediaHandler);
        break;
    }

    final random = Random();
    selectedTracks.shuffle(random);

    if (selectedTracks.length > count) {
      selectedTracks = selectedTracks.sublist(0, count);
    } else if (selectedTracks.length < count) {
      // Fill remaining with random tracks from all available local tracks
      final existingIds = selectedTracks.map((t) => t.trackID).toSet();
      final remaining = allTracks.where((t) => !existingIds.contains(t.trackID)).toList();
      remaining.shuffle(random);
      final needed = count - selectedTracks.length;
      selectedTracks.addAll(remaining.take(needed));
    }

    return selectedTracks;
  }

  static Future<List<Track>> _getMostPlayedTracks(dynamic db, MediaHandler mediaHandler) async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final rows = await db.rawQuery('''
        SELECT t.track_id, t.title, t.artist, t.duration, COUNT(lh.history_id) as play_count
        FROM Tracks t
        JOIN ListeningHistory lh ON t.track_id = lh.track_id
        WHERE lh.timestamp >= ?
        GROUP BY t.track_id
        ORDER BY play_count DESC
        LIMIT 50
      ''', [oneWeekAgo]);

      if (rows.isNotEmpty) {
        return rows.map<Track>((row) => Track(
          trackID: row['track_id'] as int,
          title: row['title'] as String,
          artist: row['artist'] as String,
          duration: row['duration'] as String,
          downloaded: true,
          contributor: '',
        )).toList();
      }
    } catch (e) {
      print('Error querying most played tracks: $e');
    }
    return await mediaHandler.getAllTracks();
  }

  static Future<List<Track>> _getLeastPlayedTracks(dynamic db, MediaHandler mediaHandler) async {
    try {
      final rows = await db.rawQuery('''
        SELECT t.track_id, t.title, t.artist, t.duration, COUNT(lh.history_id) as play_count
        FROM Tracks t
        LEFT JOIN ListeningHistory lh ON t.track_id = lh.track_id
        GROUP BY t.track_id
        ORDER BY play_count ASC
        LIMIT 50
      ''');

      if (rows.isNotEmpty) {
        return rows.map<Track>((row) => Track(
          trackID: row['track_id'] as int,
          title: row['title'] as String,
          artist: row['artist'] as String,
          duration: row['duration'] as String,
          downloaded: true,
          contributor: '',
        )).toList();
      }
    } catch (e) {
      print('Error querying least played tracks: $e');
    }
    return await mediaHandler.getAllTracks();
  }

  static Future<List<Track>> _getMixItUpTracks(dynamic db, MediaHandler mediaHandler) async {
    try {
      final playlistRows = await db.rawQuery('''
        SELECT playlist_id FROM Playlists ORDER BY RANDOM() LIMIT 3
      ''');

      if (playlistRows.isNotEmpty) {
        final ids = playlistRows.map((r) => r['playlist_id'] as int).toList();
        final placeholders = List.filled(ids.length, '?').join(',');

        final trackRows = await db.rawQuery('''
          SELECT DISTINCT t.track_id, t.title, t.artist, t.duration
          FROM Tracks t
          JOIN PlaylistTracks pt ON t.track_id = pt.track_id
          WHERE pt.playlist_id IN ($placeholders)
        ''', ids);

        if (trackRows.isNotEmpty) {
          return trackRows.map<Track>((row) => Track(
            trackID: row['track_id'] as int,
            title: row['title'] as String,
            artist: row['artist'] as String,
            duration: row['duration'] as String,
            downloaded: true,
            contributor: '',
          )).toList();
        }
      }
    } catch (e) {
      print('Error querying mix it up tracks: $e');
    }
    return await mediaHandler.getAllTracks();
  }
}
