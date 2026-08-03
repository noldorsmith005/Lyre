import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';



class UploadModal extends StatefulWidget {
  final Function(String title, String artist, String mediaPath, String coverPath, bool hidden) onUpload;
  final bool hasHiddenAccess;
  final String? errorMessage;

  const UploadModal({
    Key? key,
    required this.onUpload,
    this.hasHiddenAccess = false,
    this.errorMessage,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required Function(String, String, String, String, bool) onUpload,
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

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _mediaPath = result.files.single.path;
      });
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _coverPath = result.files.single.path;
      });
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
        onPressed: onPressed,
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
                  Icon(Icons.cloud_upload_rounded, color: themeColor, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Upload Track',
                    style: TextStyle(
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
                              _buildFileButton('Select a cover file', _pickCover, _coverPath != null),
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
                        _buildFileButton('Select a cover file', _pickCover, _coverPath != null),
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
                      activeColor: themeColor,
                      onChanged: (val) {
                        setState(() {
                          _isHidden = val;
                        });
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    elevation: 4,
                    shadowColor: themeColor.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    if (_mediaPath != null && _coverPath != null) {
                      widget.onUpload(
                        _titleController.text,
                        _artistController.text,
                        _mediaPath!,
                        _coverPath!,
                        _isHidden,
                      );
                    }
                  },
                  child: const Text(
                    'Upload',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (widget.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  widget.errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 13,
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
