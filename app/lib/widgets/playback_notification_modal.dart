import 'dart:ui';
import 'package:flutter/material.dart';
import '../screens/playback_screen.dart';
import '../services/listening_stats_service.dart';

class PlaybackNotificationModal extends StatelessWidget {
  final MonthlyPlaybackStats stats;
  final VoidCallback onViewPlayback;

  const PlaybackNotificationModal({
    super.key,
    required this.stats,
    required this.onViewPlayback,
  });

  static Future<void> show(
    BuildContext context, {
    required MonthlyPlaybackStats stats,
    required VoidCallback onViewPlayback,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: PlaybackNotificationModal(
          stats: stats,
          onViewPlayback: onViewPlayback,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PlaybackThemePalette.getPalette(stats.themeColor);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.gradientColors.isNotEmpty
                ? palette.gradientColors
                : [const Color(0xFF1E1E2E), const Color(0xFF0F0F1A)],
          ),
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: palette.accent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'LYRE PLAYBACK',
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [palette.primary, palette.secondary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.graphic_eq,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${stats.monthYearLabel} Summary',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your monthly playback metrics are ready to view. Check out your top tracks, artists, and listening stats.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Minutes', '${stats.totalMinutes}', palette.accent),
                    Container(
                      width: 1,
                      height: 28,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    _buildStatItem('Plays', '${stats.totalPlays}', palette.accent),
                    if (stats.topArtists.isNotEmpty) ...[
                      Container(
                        width: 1,
                        height: 28,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      _buildStatItem('Top Artist', stats.topArtists.first.artistName, palette.accent),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onViewPlayback();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                  shadowColor: palette.primary.withValues(alpha: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.play_arrow_rounded, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'View Playback',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white60,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color accentColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
