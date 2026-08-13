import 'package:flutter/material.dart';
import '../models/track.dart';
import 'track_cover_image.dart';

class PlaylistCoverImage extends StatelessWidget {
  final List<Track>? tracks;
  final List<int>? trackIDs;
  final String? appDataPath;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? fallback;

  const PlaylistCoverImage({
    super.key,
    this.tracks,
    this.trackIDs,
    required this.appDataPath,
    this.width,
    this.height,
    this.borderRadius,
    this.fallback,
  });

  List<int> _extractCollageTrackIDs() {
    if (tracks != null && tracks!.isNotEmpty) {
      final n = tracks!.length;
      final i0 = 0;
      final i1 = (n * 0.25).floor().clamp(0, n - 1);
      final i2 = (n * 0.50).floor().clamp(0, n - 1);
      final i3 = n - 1;
      return [
        tracks![i0].trackID,
        tracks![i1].trackID,
        tracks![i2].trackID,
        tracks![i3].trackID,
      ];
    } else if (trackIDs != null && trackIDs!.isNotEmpty) {
      if (trackIDs!.length >= 4) {
        return trackIDs!.sublist(0, 4);
      }
      final n = trackIDs!.length;
      final i0 = 0;
      final i1 = (n * 0.25).floor().clamp(0, n - 1);
      final i2 = (n * 0.50).floor().clamp(0, n - 1);
      final i3 = n - 1;
      return [
        trackIDs![i0],
        trackIDs![i1],
        trackIDs![i2],
        trackIDs![i3],
      ];
    }
    return [];
  }

  Widget _buildFallback(double? effectiveWidth, double? effectiveHeight) {
    if (fallback != null) return fallback!;
    final iconSize = effectiveWidth != null ? (effectiveWidth * 0.4).clamp(16.0, 48.0) : 32.0;
    return Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Center(
        child: Icon(
          Icons.music_note,
          size: iconSize,
          color: const Color(0xFF555555),
        ),
      ),
    );
  }

  Widget _buildTile(int trackID, double tileIconSize) {
    return TrackCoverImage(
      trackID: trackID,
      appDataPath: appDataPath,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      fallback: Container(
        color: const Color(0xFF1E1E1E),
        child: Center(
          child: Icon(
            Icons.music_note,
            size: tileIconSize,
            color: const Color(0xFF444444),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = _extractCollageTrackIDs();
    if (ids.isEmpty) {
      return _buildFallback(width, height);
    }

    final tileIconSize = width != null ? (width! * 0.2).clamp(12.0, 24.0) : 16.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTile(ids[0], tileIconSize)),
                Expanded(child: _buildTile(ids[1], tileIconSize)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTile(ids[2], tileIconSize)),
                Expanded(child: _buildTile(ids[3], tileIconSize)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
