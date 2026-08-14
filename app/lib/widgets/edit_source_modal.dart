import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../services/theme_service.dart';
import 'confirmation_dialog.dart';

class EditSourceModal extends StatefulWidget {
  final Track track;
  final String initialTitle;
  final String initialArtist;
  final bool initialHidden;
  final bool hasHiddenAccess;
  final Future<void> Function(
    String title,
    String artist,
    String? mediaPath,
    String? coverPath,
    bool hidden,
    Function(double progress, String status) updateProgress,
  ) onSave;
  final Future<void> Function(
    Function(double progress, String status) updateProgress,
  ) onDeleteFromServer;
  final VoidCallback? onComplete;

  const EditSourceModal({
    super.key,
    required this.track,
    required this.initialTitle,
    required this.initialArtist,
    this.initialHidden = false,
    this.hasHiddenAccess = false,
    required this.onSave,
    required this.onDeleteFromServer,
    this.onComplete,
  });

  static void show(
    BuildContext context, {
    required Track track,
    required String initialTitle,
    required String initialArtist,
    bool initialHidden = false,
    bool hasHiddenAccess = false,
    required Future<void> Function(
      String title,
      String artist,
      String? mediaPath,
      String? coverPath,
      bool hidden,
      Function(double progress, String status) updateProgress,
    ) onSave,
    required Future<void> Function(
      Function(double progress, String status) updateProgress,
    ) onDeleteFromServer,
    VoidCallback? onComplete,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: EditSourceModal(
          track: track,
          initialTitle: initialTitle,
          initialArtist: initialArtist,
          initialHidden: initialHidden,
          hasHiddenAccess: hasHiddenAccess,
          onSave: onSave,
          onDeleteFromServer: onDeleteFromServer,
          onComplete: onComplete,
        ),
      ),
    );
  }

  @override
  _EditSourceModalState createState() => _EditSourceModalState();
}

class _EditSourceModalState extends State<EditSourceModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  String? _mediaPath;
  String? _coverPath;
  late bool _isHidden;

  bool _isProcessing = false;
  bool _isComplete = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _artistController = TextEditingController(text: widget.initialArtist);
    _isHidden = widget.initialHidden;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_isProcessing || _isComplete) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _mediaPath = result.files.single.path;
      });
    }
  }

  Future<void> _pickCover() async {
    if (_isProcessing || _isComplete) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _coverPath = result.files.single.path;
      });
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _error = 'Track title cannot be empty.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _isComplete = false;
      _progress = 0.05;
      _statusText = 'Preparing update...';
      _error = null;
    });

    try {
      await widget.onSave(
        title,
        artist,
        _mediaPath,
        _coverPath,
        _isHidden,
        (double p, String s) {
          if (mounted) {
            setState(() {
              _progress = p;
              _statusText = s;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isComplete = true;
          _progress = 1.0;
          _statusText = 'Update Complete!';
        });
        widget.onComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isComplete = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    if (_isProcessing || _isComplete) return;

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Remove from Server',
      message: 'Are you sure you want to permanently delete "${widget.track.title}" from the server? This will remove all local downloads, play history, and playlist references.',
      confirmText: 'Delete Forever',
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _isComplete = false;
      _progress = 0.10;
      _statusText = 'Deleting track from server and references...';
      _error = null;
    });

    try {
      await widget.onDeleteFromServer(
        (double p, String s) {
          if (mounted) {
            setState(() {
              _progress = p;
              _statusText = s;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isComplete = true;
          _progress = 1.0;
          _statusText = 'Track Deleted Successfully';
        });
        widget.onComplete?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isComplete = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return Container(
      width: double.infinity,
      height: 42,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        border: Border.all(color: const Color(0xFF2E2E3A), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        enabled: !_isProcessing && !_isComplete,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF888888)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFileButton(String defaultText, VoidCallback onPressed, String? filePath, VoidCallback onClear) {
    final themeColor = context.watch<ThemeService>().themeColor;
    final hasFile = filePath != null;

    return Container(
      width: double.infinity,
      height: 42,
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasFile ? themeColor.withValues(alpha: 0.25) : const Color(0xFF2A2A36),
                side: BorderSide(color: hasFile ? themeColor : const Color(0xFF3A3A4A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(
                hasFile ? Icons.check_circle_rounded : Icons.folder_open_rounded,
                color: hasFile ? themeColor : Colors.white70,
                size: 18,
              ),
              label: Text(
                hasFile ? 'Replacement Selected' : defaultText,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasFile ? themeColor : Colors.white,
                  fontSize: 13,
                  fontWeight: hasFile ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onPressed: (_isProcessing || _isComplete) ? null : onPressed,
            ),
          ),
          if (hasFile && !_isProcessing && !_isComplete) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Clear selection',
              icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
              onPressed: onClear,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<ThemeService>().themeColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xEE18181E),
          border: Border.all(color: const Color(0xFF2E2E3A), width: 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isComplete ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                    color: _isComplete ? const Color(0xFF4CAF50) : themeColor,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isComplete ? 'Changes Saved' : 'Edit Track Source',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 440;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildTextField('Title', _titleController),
                              _buildTextField('Artist', _artistController),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _buildFileButton(
                                'Replace Audio (optional)',
                                _pickMedia,
                                _mediaPath,
                                () => setState(() => _mediaPath = null),
                              ),
                              _buildFileButton(
                                'Replace Cover (optional)',
                                _pickCover,
                                _coverPath,
                                () => setState(() => _coverPath = null),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildTextField('Title', _titleController),
                        _buildTextField('Artist', _artistController),
                        _buildFileButton(
                          'Replace Audio (optional)',
                          _pickMedia,
                          _mediaPath,
                          () => setState(() => _mediaPath = null),
                        ),
                        _buildFileButton(
                          'Replace Cover (optional)',
                          _pickCover,
                          _coverPath,
                          () => setState(() => _coverPath = null),
                        ),
                      ],
                    );
                  }
                },
              ),
              if (widget.hasHiddenAccess) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Hidden Track', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isHidden,
                      activeThumbColor: themeColor,
                      onChanged: (_isProcessing || _isComplete)
                          ? null
                          : (val) {
                              setState(() {
                                _isHidden = val;
                              });
                            },
                    ),
                  ],
                ),
              ],
              if (_isProcessing || _isComplete) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF2A2A36),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isComplete ? const Color(0xFF4CAF50) : themeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _statusText,
                        style: TextStyle(
                          color: _isComplete ? const Color(0xFF4CAF50) : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: TextStyle(
                        color: _isComplete ? const Color(0xFF4CAF50) : themeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Remove from Server Button (Danger Style)
                  if (!_isComplete) ...[
                    SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD32F2F), width: 1.2),
                          backgroundColor: const Color(0x1AD32F2F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF5252), size: 18),
                        label: const Text(
                          'Remove from Server',
                          style: TextStyle(color: Color(0xFFFF5252), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isProcessing ? null : _handleDelete,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],

                  // Submit / Done Button
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isComplete ? const Color(0xFF4CAF50) : themeColor,
                        elevation: 4,
                        shadowColor: (_isComplete ? const Color(0xFF4CAF50) : themeColor).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : (_isComplete
                              ? () => Navigator.of(context).pop()
                              : _handleSave),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isComplete ? 'Done' : 'Submit',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x33FF5252),
                    border: Border.all(color: const Color(0xFFFF5252), width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFF5252),
                            fontSize: 13,
                          ),
                        ),
                      ),
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
