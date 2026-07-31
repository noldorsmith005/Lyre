import 'dart:io';
import 'package:flutter/material.dart';



class TrackCoverImage extends StatelessWidget {
  final int? trackID;
  final String? appDataPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;

  const TrackCoverImage({
    super.key,
    required this.trackID,
    required this.appDataPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (trackID == null || appDataPath == null || appDataPath!.isEmpty) {
      return fallback;
    }

    final coverFile = File('$appDataPath/cover/$trackID.jpg');
    if (!coverFile.existsSync()) {
      return fallback;
    }

    int modTime = 0;
    try {
      modTime = coverFile.lastModifiedSync().millisecondsSinceEpoch;
    } catch (_) {
      // Fallback
    }

    return Image.file(
      coverFile,
      key: ValueKey('track_cover_${trackID}_$modTime'),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
