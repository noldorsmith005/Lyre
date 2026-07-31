import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../services/theme_service.dart';
import '../track_cover_image.dart';



class MobileQueueModal extends StatelessWidget {
  final String appDataPath;

  const MobileQueueModal({Key? key, required this.appDataPath}) : super(key: key);

  static Future<void> show(BuildContext context, {required String appDataPath}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileQueueModal(appDataPath: appDataPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<ThemeService>().themeColor;
    final audioService = Provider.of<AudioPlayerService>(context);
    final queue = audioService.queue;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E14),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: const Color(0xFF222232), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 25,
                spreadRadius: 4,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag Handle Bar
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333346),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              
              // Queue Header & Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.queue_music_rounded, color: themeColor, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Queue (${queue.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    if (queue.isNotEmpty)
                      InkWell(
                        onTap: () => audioService.clearQueue(),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A26),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF2C2C3E), width: 1),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF9999AA)),
                              SizedBox(width: 6),
                              Text(
                                'Clear All',
                                style: TextStyle(color: Color(0xFF9999AA), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF1F1F2E), height: 20, thickness: 1),

              // Queue List
              Expanded(
                child: queue.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.music_off_outlined, color: Color(0xFF444456), size: 48),
                            SizedBox(height: 12),
                            Text(
                              'Queue is empty',
                              style: TextStyle(color: Color(0xFF777788), fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: queue.length,
                        itemBuilder: (context, index) {
                          final track = queue[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14141E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF222232), width: 1),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: TrackCoverImage(
                                  trackID: track.trackID,
                                  appDataPath: appDataPath,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  fallback: Container(
                                    width: 42,
                                    height: 42,
                                    color: const Color(0xFF1F1F2E),
                                    child: const Icon(Icons.music_note, color: Color(0xFF666677), size: 20),
                                  ),
                                ),
                              ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF888899), fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF666677), size: 20),
                                onPressed: () => audioService.removeFromQueue(track),
                                tooltip: 'Remove',
                              ),
                              onTap: () {
                                audioService.playFromQueue(track);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
