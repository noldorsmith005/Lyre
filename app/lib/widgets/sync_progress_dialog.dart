import 'dart:ui';
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

  static Future<bool> show(BuildContext context, ServerClient serverClient) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: SyncProgressDialog(serverClient: serverClient),
      ),
    );
    return result ?? false;
  }

  @override
  State<SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends State<SyncProgressDialog> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late SyncProgress _currentProgress;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _currentProgress = widget.serverClient.syncProgressNotifier.value;
    widget.serverClient.syncProgressNotifier.addListener(_onProgressChanged);
    widget.serverClient.isSyncingNotifier.addListener(_onIsSyncingChanged);
  }

  void _onProgressChanged() {
    if (mounted) {
      setState(() {
        _currentProgress = widget.serverClient.syncProgressNotifier.value;
      });
    }
  }

  void _onIsSyncingChanged() {
    if (mounted && !widget.serverClient.isSyncingNotifier.value) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop(true);
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

    return PopScope(
      canPop: true,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 20,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xEE14141C),
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
                      turns: Tween<double>(begin: 1.0, end: 0.0).animate(_rotationController),
                      child: Icon(
                        Icons.sync_rounded,
                        color: themeColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Syncing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeColor.withValues(alpha: 0.4)),
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
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.7), size: 20),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop(false);
                    },
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Progress bar
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
              if (_currentProgress.trackProgress != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          tween: Tween<double>(begin: 0.0, end: _currentProgress.trackProgress!.clamp(0.0, 1.0)),
                          builder: (context, value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 4,
                              backgroundColor: const Color(0xFF242432),
                              valueColor: AlwaysStoppedAnimation<Color>(themeColor.withValues(alpha: 0.6)),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_currentProgress.trackProgressLabel != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        _currentProgress.trackProgressLabel!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 16),
              // Status and details
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentProgress.status,
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
              if (_currentProgress.detail != null && _currentProgress.detail!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    _currentProgress.detail!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

