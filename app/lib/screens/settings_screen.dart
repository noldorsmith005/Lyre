import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/server_client.dart';
import '../services/theme_service.dart';
import '../widgets/confirmation_dialog.dart';
import 'mobile/search_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onLogoutPressed;
  final ServerClient? serverClient;
  final dynamic mediaHandler;
  final String? appDataPath;
  final List<Playlist>? playlists;
  final bool isServerConnected;
  final Function(Track)? onDownloadTrack;
  final Function(Track)? onRemoveDownloadTrack;
  final VoidCallback? onRlsPressed;
  final Function(List<Track>)? onViewUnusedDownloads;

  const SettingsScreen({
    super.key,
    this.onLogoutPressed,
    this.serverClient,
    this.mediaHandler,
    this.appDataPath,
    this.playlists,
    this.isServerConnected = false,
    this.onDownloadTrack,
    this.onRemoveDownloadTrack,
    this.onRlsPressed,
    this.onViewUnusedDownloads,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isResettingTracking = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final themeColor = themeService.themeColor;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final List<Map<String, dynamic>> themeOptions = [
      {'key': 'red', 'name': 'Red', 'color': const Color.fromARGB(255, 200, 30, 30)},
      {'key': 'green', 'name': 'Green', 'color': const Color(0xFF0F5A2B)},
      {'key': 'blue', 'name': 'Blue', 'color': const Color(0xFF0F3178)},
      {'key': 'purple', 'name': 'Purple', 'color': const Color(0xFF4A148C)},
    ];

    final serverClient = widget.serverClient;
    final mediaHandler = widget.mediaHandler;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101016),
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 40.0 + bottomInset),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            const Text(
              "Appearance & Theme",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF14141E),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, color: themeColor, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        "Accent Theme Color",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Select an accent color for player controls, buttons, and app highlights.",
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: themeOptions.map((opt) {
                      final bool isSelected = themeService.themeColorKey == opt['key'];
                      final Color color = opt['color'] as Color;
                      final String name = opt['name'] as String;

                      return GestureDetector(
                        onTap: () {
                          themeService.setThemeColor(opt['key'] as String);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.25) : const Color(0xFF0E0E14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey[400],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (mediaHandler != null) ...[
              const SizedBox(height: 24),
              const Text(
                "Manage Unused Downloads",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF14141E),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Clean up tracks stored locally that are not included in any playlist.",
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[300],
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final unused = await mediaHandler.getUnusedDownloadedTracks();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            if (widget.onViewUnusedDownloads != null) {
                              widget.onViewUnusedDownloads!(unused.cast<Track>());
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SearchScreen(
                                    mediaHandler: mediaHandler,
                                    serverClient: serverClient,
                                    isServerConnected: widget.isServerConnected,
                                    onRlsPressed: widget.onRlsPressed,
                                    onDownloadTrack: widget.onDownloadTrack,
                                    onRemoveDownloadTrack: widget.onRemoveDownloadTrack,
                                    appDataPath: widget.appDataPath ?? '',
                                    allPlaylists: widget.playlists ?? [],
                                    initialTracks: unused.cast<Track>(),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text(
                          'View Unused Downloads',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A1515),
                          foregroundColor: const Color(0xFFFF4444),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF552222)),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final confirmed = await ConfirmationDialog.show(
                            context,
                            title: 'Clear Unused Downloads',
                            message: 'Are you sure you want to delete all downloaded tracks that are not part of any playlist?',
                            confirmText: 'Clear',
                          );
                          if (confirmed == true && mediaHandler != null) {
                            final unused = await mediaHandler.getUnusedDownloadedTracks();
                            for (final track in unused) {
                              if (serverClient != null) {
                                await serverClient.removeDownload(track);
                              } else {
                                await mediaHandler.deleteTrack(track);
                              }
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cleared ${unused.length} unused download(s).'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text(
                          'Clear Unused Downloads',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (serverClient != null && serverClient.registered()) ...[
              const SizedBox(height: 24),
              const Text(
                "Server Tracking",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF14141E),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reset cloud-tracked playlists and download records by clearing server tracking and bulk re-syncing from this device.",
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[300],
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isResettingTracking
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final confirmed = await ConfirmationDialog.show(
                                  context,
                                  title: 'Reset Server Tracking',
                                  message:
                                      'Are you sure you want to reset server tracking? This will clear all tracked playlists and downloads on the server and re-sync them from this device. Play history and metrics will not be affected.',
                                  confirmText: 'Reset Tracking',
                                );
                                if (confirmed != true || !mounted) return;
                                setState(() => _isResettingTracking = true);
                                final success = await serverClient.resetServerTracking();
                                if (!mounted) return;
                                setState(() => _isResettingTracking = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Server tracking reset and re-synced successfully.'
                                          : 'Failed to reset server tracking. Check server connection.',
                                    ),
                                  ),
                                );
                              },
                        icon: _isResettingTracking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.cloud_sync_rounded, size: 18),
                        label: Text(
                          _isResettingTracking ? 'Resetting Tracking...' : 'Reset Server Tracking',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              "Account",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF14141E),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, color: themeColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (serverClient != null && serverClient.registered())
                              ? (serverClient.username != null && serverClient.username.toString().isNotEmpty
                                  ? serverClient.username.toString()
                                  : 'Connected User')
                              : 'Guest Account',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  if (widget.onLogoutPressed != null && (serverClient == null || serverClient.registered())) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF262626), height: 1),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A1515),
                          foregroundColor: const Color(0xFFFF4444),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF552222)),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onLogoutPressed!();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'Log Out',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
),
),
),
);
  }
}


