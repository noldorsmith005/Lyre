import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../services/media_handler.dart';
import '../services/theme_service.dart';
import '../services/vibe_queue_service.dart';



class VibeQueueModal extends StatefulWidget {
  final MediaHandler mediaHandler;
  final Function(List<Track> tracks, VibeType vibe) onQueueVibe;

  const VibeQueueModal({
    super.key,
    required this.mediaHandler,
    required this.onQueueVibe,
  });

  static Future<void> show(
    BuildContext context, {
    required MediaHandler mediaHandler,
    required Function(List<Track> tracks, VibeType vibe) onQueueVibe,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: VibeQueueModal(
          mediaHandler: mediaHandler,
          onQueueVibe: onQueueVibe,
        ),
      ),
    );
  }

  @override
  State<VibeQueueModal> createState() => _VibeQueueModalState();
}

class _VibeQueueModalState extends State<VibeQueueModal> {
  VibeType _selectedVibe = VibeType.myCurrentFavs;
  bool _isLoading = false;

  Future<void> _handleQueue() async {
    setState(() {
      _isLoading = true;
    });

    final tracks = await VibeQueueService.generateQueue(
      vibe: _selectedVibe,
      mediaHandler: widget.mediaHandler,
      count: 20,
    );

    if (mounted) {
      Navigator.of(context).pop();
      widget.onQueueVibe(tracks, _selectedVibe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<ThemeService>().themeColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xEE141418),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E2E3A), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with dismiss icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: themeColor, size: 26),
                    const SizedBox(width: 10),
                    const Text(
                      'What\'s the Vibe Today?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF888888)),
                  onPressed: () => Navigator.of(context).pop(),
                  hoverColor: Colors.white10,
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Selection Options
            Column(
              children: VibeType.values.map((vibe) {
                final isSelected = _selectedVibe == vibe;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => setState(() => _selectedVibe = vibe),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? themeColor.withValues(alpha: 0.15)
                            : const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? themeColor : const Color(0xFF2A2A36),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? themeColor : const Color(0xFF888888),
                            size: 20,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vibe.title,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFFCCCCCC),
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Description Box
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF181820),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF262632), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: themeColor.withValues(alpha: 0.9), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedVibe.description,
                      style: const TextStyle(
                        color: Color(0xFFBBBBBB),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Queue Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: themeColor.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _handleQueue,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.queue_music_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Queue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
