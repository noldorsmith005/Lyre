import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../models/track.dart';
import 'server_client.dart';

class TrackStat {
  final int trackID;
  final String title;
  final String artist;
  final String duration;
  final int playCount;
  final int totalDurationSeconds;

  TrackStat({
    required this.trackID,
    required this.title,
    required this.artist,
    required this.duration,
    required this.playCount,
    required this.totalDurationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'trackID': trackID,
        'title': title,
        'artist': artist,
        'duration': duration,
        'playCount': playCount,
        'totalDurationSeconds': totalDurationSeconds,
      };

  factory TrackStat.fromJson(Map<String, dynamic> json) => TrackStat(
        trackID: json['trackID'] as int? ?? 0,
        title: json['title'] as String? ?? 'Unknown Title',
        artist: json['artist'] as String? ?? 'Unknown Artist',
        duration: json['duration'] as String? ?? '3:30',
        playCount: json['playCount'] as int? ?? 1,
        totalDurationSeconds: json['totalDurationSeconds'] as int? ?? 210,
      );
}

class ArtistStat {
  final String artistName;
  final int playCount;
  final int totalMinutes;
  final String topTrackTitle;

  ArtistStat({
    required this.artistName,
    required this.playCount,
    required this.totalMinutes,
    required this.topTrackTitle,
  });

  Map<String, dynamic> toJson() => {
        'artistName': artistName,
        'playCount': playCount,
        'totalMinutes': totalMinutes,
        'topTrackTitle': topTrackTitle,
      };

  factory ArtistStat.fromJson(Map<String, dynamic> json) => ArtistStat(
        artistName: json['artistName'] as String? ?? 'Unknown Artist',
        playCount: json['playCount'] as int? ?? 1,
        totalMinutes: json['totalMinutes'] as int? ?? 1,
        topTrackTitle: json['topTrackTitle'] as String? ?? 'Top Track',
      );
}

class PercentileItem {
  final String label;
  final String percentile;
  PercentileItem({required this.label, required this.percentile});

  Map<String, dynamic> toJson() => {'label': label, 'percentile': percentile};
  factory PercentileItem.fromJson(Map<String, dynamic> json) => PercentileItem(
        label: (json['label'] ?? json['title'] ?? json['artist'] ?? '') as String,
        percentile: (json['percentile'] ?? 'Top 1%') as String,
      );
}

class TopPercentages {
  final List<PercentileItem> topTracks;
  final List<PercentileItem> topArtists;

  TopPercentages({required this.topTracks, required this.topArtists});

  Map<String, dynamic> toJson() => {
        'top_tracks': topTracks.map((e) => e.toJson()).toList(),
        'top_artists': topArtists.map((e) => e.toJson()).toList(),
      };

  factory TopPercentages.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['top_tracks'] as List<dynamic>? ?? [];
    final rawArtists = json['top_artists'] as List<dynamic>? ?? [];
    return TopPercentages(
      topTracks: rawTracks.map((e) => PercentileItem.fromJson(e as Map<String, dynamic>)).toList(),
      topArtists: rawArtists.map((e) => PercentileItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class MonthlyPlaybackStats {
  final String monthYearLabel;
  final int totalMinutes;
  final int totalPlays;
  final String percentileText;
  final int dailyAverageMinutes;
  final List<TrackStat> topTracks;
  final List<ArtistStat> topArtists;
  final TopPercentages topPercentages;
  final String themeColor;

  MonthlyPlaybackStats({
    required this.monthYearLabel,
    required this.totalMinutes,
    required this.totalPlays,
    required this.percentileText,
    required this.dailyAverageMinutes,
    required this.topTracks,
    required this.topArtists,
    required this.topPercentages,
    this.themeColor = 'Neon Cyber Violet',
  });
}

class ListeningStatsService {
  static final ListeningStatsService _instance = ListeningStatsService._internal();
  static ListeningStatsService get instance => _instance;

  ListeningStatsService._internal();

  Database? _db;

  void setDatabase(Database db) {
    _db = db;
  }

  Future<void> logPlay(Track track) async {
    if (_db == null) return;
    try {
      final now = DateTime.now().toIso8601String();
      await _db!.insert('ListeningHistory', {
        'track_id': track.trackID,
        'title': track.title,
        'artist': track.artist,
        'duration': track.duration,
        'timestamp': now,
      });
    } catch (e) {
      print('Error logging track play: $e');
    }
  }

  Future<void> syncLocalHistoryToServer(ServerClient serverClient) async {
    if (_db == null || !serverClient.registered()) return;
    try {
      final result = await _db!.rawQuery('''
        SELECT track_id, COUNT(*) as play_count
        FROM ListeningHistory
        GROUP BY track_id
      ''');
      if (result.isEmpty) return;

      final historyItems = result.map((r) => {
        'track_id': r['track_id'] as int,
        'play_count': r['play_count'] as int,
      }).toList();

      await serverClient.syncHistoryToServer(historyItems);
    } catch (e) {
      print('Error syncing history to server: $e');
    }
  }

  int _parseDurationSeconds(String durationStr) {
    if (durationStr.isEmpty) return 180;
    final parts = durationStr.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 3;
      final s = int.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    }
    return int.tryParse(durationStr) ?? 180;
  }

  String _getMonthYearLabel(DateTime now) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${monthNames[now.month - 1]} ${now.year}';
  }

  Future<MonthlyPlaybackStats> fetchAndSyncStats(ServerClient serverClient, List<Track> allLocalTracks) async {
    // 1. Try querying server stats if server is online
    if (serverClient.registered()) {
      final serverRes = await serverClient.fetchServerStats();
      if (serverRes != null) {
        final isNewRelease = (serverRes['new_release'] as int? ?? 0) == 1;
        final monthLabel = (serverRes['month_year'] as String?) ?? _getMonthYearLabel(DateTime.now());
        final totMin = (serverRes['total_minutes'] as int?) ?? 0;
        final totPlays = (serverRes['total_plays'] as int?) ?? 0;
        final dAvg = (serverRes['daily_avg_minutes'] as int?) ?? 0;
        final pctText = (serverRes['percentile_text'] as String?) ?? 'Top Music Listener';

        final rawTracks = serverRes['top_tracks'] as List<dynamic>? ?? [];
        final topTracks = rawTracks.map((t) => TrackStat.fromJson(t as Map<String, dynamic>)).toList();

        final rawArtists = serverRes['top_artists'] as List<dynamic>? ?? [];
        final topArtists = rawArtists.map((a) => ArtistStat.fromJson(a as Map<String, dynamic>)).toList();

        final rawPct = serverRes['top_percentages'] as Map<String, dynamic>? ?? {};
        final topPct = TopPercentages.fromJson(rawPct);
        final themeCol = (serverRes['theme_color'] as String?) ?? 'Neon Cyber Violet';

        final stats = MonthlyPlaybackStats(
          monthYearLabel: monthLabel,
          totalMinutes: totMin,
          totalPlays: totPlays,
          percentileText: pctText,
          dailyAverageMinutes: dAvg,
          topTracks: topTracks,
          topArtists: topArtists,
          topPercentages: topPct,
          themeColor: themeCol,
        );

        // Store to local SQLite if new release
        if (isNewRelease && _db != null) {
          final uid = int.tryParse(serverClient.userID ?? '0') ?? 0;
          await _db!.insert(
            'LocalStats',
            {
              'user_id': uid,
              'month_year': monthLabel,
              'total_minutes': totMin,
              'total_plays': totPlays,
              'daily_avg_minutes': dAvg,
              'percentile_text': pctText,
              'top_tracks_json': jsonEncode(rawTracks),
              'top_artists_json': jsonEncode(rawArtists),
              'top_percentages_json': jsonEncode(rawPct),
              'theme_color': themeCol,
              'new_release': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await serverClient.ackServerStats();
        }

        if (topTracks.isNotEmpty || totMin > 0) {
          return stats;
        }
      }
    }

    // 2. Local database fallback
    return getMonthlyStats(allLocalTracks);
  }

  Future<MonthlyPlaybackStats> getMonthlyStats(List<Track> allLocalTracks) async {
    final now = DateTime.now();
    final monthLabel = _getMonthYearLabel(now);
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    List<Map<String, dynamic>> rows = [];
    if (_db != null) {
      try {
        rows = await _db!.query(
          'ListeningHistory',
          where: 'timestamp >= ?',
          whereArgs: [startOfMonth],
        );
      } catch (e) {
        print('Error fetching history: $e');
      }
    }

    Map<int, TrackStat> trackStatsMap = {};

    for (var r in rows) {
      final tid = r['track_id'] as int;
      final title = (r['title'] as String?) ?? 'Unknown Title';
      final artist = (r['artist'] as String?) ?? 'Unknown Artist';
      final durStr = (r['duration'] as String?) ?? '3:30';
      final durSec = _parseDurationSeconds(durStr);

      if (trackStatsMap.containsKey(tid)) {
        final existing = trackStatsMap[tid]!;
        trackStatsMap[tid] = TrackStat(
          trackID: tid,
          title: title,
          artist: artist,
          duration: durStr,
          playCount: existing.playCount + 1,
          totalDurationSeconds: existing.totalDurationSeconds + durSec,
        );
      } else {
        trackStatsMap[tid] = TrackStat(
          trackID: tid,
          title: title,
          artist: artist,
          duration: durStr,
          playCount: 1,
          totalDurationSeconds: durSec,
        );
      }
    }

    List<TrackStat> sortedTracks = trackStatsMap.values.toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    sortedTracks.sort((a, b) => b.playCount.compareTo(a.playCount));
    final top5Tracks = sortedTracks.take(5).toList();

    Map<String, List<TrackStat>> byArtist = {};
    for (var ts in sortedTracks) {
      final name = ts.artist.isNotEmpty ? ts.artist : 'Top Artist';
      byArtist.putIfAbsent(name, () => []).add(ts);
    }

    List<ArtistStat> artistList = [];
    byArtist.forEach((artistName, tracks) {
      int totalPlays = 0;
      int totalSec = 0;
      tracks.sort((a, b) => b.playCount.compareTo(a.playCount));
      final topTrack = tracks.first.title;
      for (var t in tracks) {
        totalPlays += t.playCount;
        totalSec += t.totalDurationSeconds;
      }
      artistList.add(ArtistStat(
        artistName: artistName,
        playCount: totalPlays,
        totalMinutes: max(1, (totalSec / 60).round()),
        topTrackTitle: topTrack,
      ));
    });

    artistList.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
    final top5Artists = artistList.take(5).toList();

    int calcTotalSec = sortedTracks.fold(0, (sum, t) => sum + t.totalDurationSeconds);
    int totalPlaysCount = sortedTracks.fold(0, (sum, t) => sum + t.playCount);

    int totalMinutes = (calcTotalSec / 60).round();
    int dayOfMonth = max(1, now.day);
    int dailyAvg = (totalMinutes / dayOfMonth).round();

    // Compute top 2 track and artist percentiles
    final topTrackItems = top5Tracks.take(2).map((t) => PercentileItem(
      label: t.title,
      percentile: 'Top 1%',
    )).toList();

    final topArtistItems = top5Artists.take(2).map((a) => PercentileItem(
      label: a.artistName,
      percentile: 'Top 1%',
    )).toList();

    return MonthlyPlaybackStats(
      monthYearLabel: monthLabel,
      totalMinutes: totalMinutes,
      totalPlays: totalPlaysCount,
      percentileText: 'Napster Listener',
      dailyAverageMinutes: dailyAvg,
      topTracks: top5Tracks,
      topArtists: top5Artists,
      topPercentages: TopPercentages(topTracks: topTrackItems, topArtists: topArtistItems),
    );
  }
}
