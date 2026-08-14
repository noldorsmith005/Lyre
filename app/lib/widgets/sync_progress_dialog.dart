import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/server_client.dart';
import '../services/theme_service.dart';

class SyncProgressDialog extends StatefulWidget {
  final ServerClient serverClient;

  const SyncProgressDialog({
    super.key,
    required this.serverClient,
  });

  @override
  State<SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends State<SyncProgressDialog> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late SyncProgress _currentProgress;

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.serverClient.syncProgressNotifier.value;
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (widget.serverClient.isSyncingNotifier.value) {
      _rotationController.repeat();
    }

    widget.serverClient.syncProgressNotifier.addListener(_onProgressChanged);
    widget.serverClient.isSyncingNotifier.addListener(_onIsSyncingChanged);
  }

  void _onProgressChanged() {
    if (!mounted) return;
    setState(() {
      _currentProgress = widget.serverClient.syncProgressNotifier.value;
    });

    if (_currentProgress.progress >= 1.0) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
    }
  }

  void _onIsSyncingChanged() {
    if (!mounted) return;
    if (widget.serverClient.isSyncingNotifier.value) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.serverClient.syncProgressNotifier.removeListener(_onProgressChanged);
    widget.serverClient.isSyncingNotifier.removeListener(_onIsSyncingChanged);
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<ThemeService>().themeColor;
    final percentage = (_currentProgress.progress * 100).clamp(0, 100).toInt();
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.90).clamp(320.0, 460.0);

    return PopScope(
      canPop: true,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: dialogWidth,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFA14141C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: themeColor.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 24,
                spreadRadius: 4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: RotationTransition(
                      turns: _rotationController,
                      child: Icon(
                        Icons.autorenew_rounded,
                        color: themeColor,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Syncing Library',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (_currentProgress.stepIndex > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Step ${_currentProgress.stepIndex} of ${_currentProgress.totalSteps}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeColor.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.7), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Primary Progress Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _currentProgress.stage.isNotEmpty ? _currentProgress.stage : 'Syncing...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  tween: Tween<double>(begin: 0.0, end: _currentProgress.progress.clamp(0.0, 1.0)),
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF242432),
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    );
                  },
                ),
              ),

              // Secondary Progress Section (Track Downloading Phase)
              if (_currentProgress.isDownloadingPhase && (_currentProgress.totalTracksToDownload > 0)) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: themeColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.download_rounded,
                                color: themeColor,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _currentProgress.trackProgressLabel ??
                                    'Track ${_currentProgress.currentTrackIndex} of ${_currentProgress.totalTracksToDownload}',
                                style: TextStyle(
                                  color: themeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (_currentProgress.trackProgress != null)
                            Text(
                              '${((_currentProgress.trackProgress!).clamp(0.0, 1.0) * 100).toInt()}%',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          tween: Tween<double>(
                            begin: 0.0,
                            end: (_currentProgress.trackProgress ?? 0.0).clamp(0.0, 1.0),
                          ),
                          builder: (context, value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 5,
                              backgroundColor: const Color(0xFF2A2A3A),
                              valueColor: AlwaysStoppedAnimation<Color>(themeColor.withValues(alpha: 0.75)),
                            );
                          },
                        ),
                      ),
                      if (_currentProgress.currentTrackTitle != null &&
                          _currentProgress.currentTrackTitle!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.music_note_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _currentProgress.currentTrackTitle!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
