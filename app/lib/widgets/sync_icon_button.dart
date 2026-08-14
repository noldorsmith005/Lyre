import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/server_client.dart';
import '../services/theme_service.dart';
import 'sync_progress_dialog.dart';

class SyncIconButton extends StatefulWidget {
  final ServerClient serverClient;
  final double size;
  final EdgeInsetsGeometry padding;

  const SyncIconButton({
    super.key,
    required this.serverClient,
    this.size = 44.0,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<SyncIconButton> createState() => _SyncIconButtonState();
}

class _SyncIconButtonState extends State<SyncIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    widget.serverClient.isSyncingNotifier.addListener(_updateAnimation);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.serverClient.isSyncingNotifier.value) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => SyncProgressDialog(
        serverClient: widget.serverClient,
      ),
    );
  }

  @override
  void dispose() {
    widget.serverClient.isSyncingNotifier.removeListener(_updateAnimation);
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<ThemeService>().themeColor;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.serverClient.isOfflineNotifier,
      builder: (context, isOffline, child) {
        if (isOffline) {
          return Padding(
            padding: widget.padding,
            child: Tooltip(
              message: 'Offline Mode',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: themeColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Offline',
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: widget.serverClient.isSyncingNotifier,
          builder: (context, isSyncing, child) {
            if (!isSyncing) return const SizedBox.shrink();

            return Padding(
              padding: widget.padding,
              child: Tooltip(
                message: 'Syncing Library (Tap for progress)',
                child: GestureDetector(
                  onTap: () => _showSyncDialog(context),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF181818),
                        border: Border.all(
                          color: themeColor.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: RotationTransition(
                          turns: Tween<double>(begin: 1.0, end: 0.0).animate(_rotationController),
                          child: Icon(
                            Icons.sync_rounded,
                            color: themeColor,
                            size: widget.size * 0.55,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
