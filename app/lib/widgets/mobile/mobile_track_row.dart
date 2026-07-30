import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/track.dart';
import '../../services/theme_service.dart';
import '../track_cover_image.dart';

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
        child: Row(
          children: [
            Icon(Icons.queue_music, color: context.watch<ThemeService>().themeColor),
            const SizedBox(width: 12),
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
            color: Color(0xFF121212),
            border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E), width: 1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: TrackCoverImage(
                  trackID: track.trackID,
                  appDataPath: appDataPath,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  fallback: Image.asset(
                    'assets/default.jpg', // fallback asset
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 48,
                      height: 48,
                      color: const Color(0xFF181818),
                      child: const Icon(Icons.music_note, color: Color(0xFF757575)),
                    ),
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
                        fontSize: 15,
                        color: isPlaying ? context.watch<ThemeService>().themeColor : Colors.white,
                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFB3B3B3),
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
                  color: Color(0xFF757575),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
