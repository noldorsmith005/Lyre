import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/track.dart';

class MobileTrackRow extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onQueue;
  final String appDataPath;

  const MobileTrackRow({
    Key? key,
    required this.track,
    required this.isPlaying,
    required this.onTap,
    required this.onLongPress,
    required this.onQueue,
    required this.appDataPath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final coverFile = File('$appDataPath/cover/${track.trackID}.jpg');
    final hasCover = coverFile.existsSync();

    return Dismissible(
      key: ValueKey('dismiss_${track.trackID}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        onQueue();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${track.title} added to queue', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1E1E1E),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        color: const Color(0xFF161616),
        child: const Row(
          children: [
            Icon(Icons.queue_music, color: Color(0xFFFF0000)),
            SizedBox(width: 12),
            Text(
              'Add to Queue',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A), width: 1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: hasCover
                    ? Image.file(
                        coverFile,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/default.jpg', // fallback asset
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFF1E1E1E),
                          child: const Icon(Icons.music_note, color: Color(0xFF555555)),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: isPlaying ? const Color(0xFFFF0000) : const Color(0xFFE8E8E8),
                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                track.duration,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF555555),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
