import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class UploadModal extends StatefulWidget {
  final Future<void> Function(
    String title,
    String artist,
    String mediaPath,
    String? coverPath,
    bool hidden,
    Function(double progress, String status) updateProgress,
  ) onUpload;
  final bool hasHiddenAccess;
  final String? errorMessage;

  const UploadModal({
    super.key,
    required this.onUpload,
    this.hasHiddenAccess = false,
    this.errorMessage,
  });

  static void show(
    BuildContext context, {
    required Future<void> Function(
      String title,
      String artist,
      String mediaPath,
      String? coverPath,
      bool hidden,
      Function(double progress, String status) updateProgress,
    ) onUpload,
    bool hasHiddenAccess = false,
    String? errorMessage,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: UploadModal(
          onUpload: onUpload,
          hasHiddenAccess: hasHiddenAccess,
          errorMessage: errorMessage,
        ),
      ),
    );
  }

  @override
  _UploadModalState createState() => _UploadModalState();
}

class _UploadModalState extends State<UploadModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  String? _mediaPath;
  String? _coverPath;
  bool _isHidden = false;

  bool _isUploading = false;
  bool _isComplete = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.errorMessage;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_isUploading || _isComplete) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _mediaPath = result.files.single.path;
      });
    }
  }

  Future<void> _pickCover() async {
    if (_isUploading || _isComplete) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _coverPath = result.files.single.path;
      });
    }
  }

  Future<void> _startUpload() async {
    if (_mediaPath == null || _isUploading || _isComplete) return;

    setState(() {
      _isUploading = true;
      _isComplete = false;
      _progress = 0.05;
      _statusText = 'Preparing upload...';
      _error = null;
    });

    try {
      await widget.onUpload(
        _titleController.text.trim(),
        _artistController.text.trim(),
        _mediaPath!,
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
          _isUploading = false;
          _isComplete = true;
          _progress = 1.0;
          _statusText = 'Upload Complete!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
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
        enabled: !_isUploading && !_isComplete,
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

  Widget _buildFileButton(String text, VoidCallback onPressed, bool hasFile) {
    final themeColor = context.watch<ThemeService>().themeColor;
    return Container(
      width: double.infinity,
      height: 42,
      margin: const EdgeInsets.only(bottom: 14),
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
          hasFile ? 'File Selected' : text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: hasFile ? themeColor : Colors.white,
            fontSize: 13,
            fontWeight: hasFile ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onPressed: (_isUploading || _isComplete) ? null : onPressed,
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
                    _isComplete
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_rounded,
                    color: _isComplete ? const Color(0xFF4CAF50) : themeColor,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isComplete ? 'Upload Successful' : 'Upload Track',
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
                              _buildFileButton('Select a media file', _pickMedia, _mediaPath != null),
                              _buildFileButton('Select a cover file (optional)', _pickCover, _coverPath != null),
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
                        _buildFileButton('Select a media file', _pickMedia, _mediaPath != null),
                        _buildFileButton('Select a cover file (optional)', _pickCover, _coverPath != null),
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
                      onChanged: (_isUploading || _isComplete)
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
              if (_isUploading || _isComplete) ...[
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
              const SizedBox(height: 18),
              SizedBox(
                width: 260,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isComplete ? const Color(0xFF4CAF50) : themeColor,
                    elevation: 4,
                    shadowColor: (_isComplete ? const Color(0xFF4CAF50) : themeColor).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isUploading
                      ? null
                      : (_isComplete
                          ? () => Navigator.of(context).pop()
                          : _startUpload),
                  child: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isComplete ? 'Done' : 'Upload',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
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
