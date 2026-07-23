import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class UploadModal extends StatefulWidget {
  final Function(String title, String artist, String mediaPath, String coverPath) onUpload;
  final String? errorMessage;

  const UploadModal({
    Key? key,
    required this.onUpload,
    this.errorMessage,
  }) : super(key: key);

  static void show(BuildContext context, {required Function(String, String, String, String) onUpload, String? errorMessage}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: UploadModal(onUpload: onUpload, errorMessage: errorMessage),
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
      width: 260,
      height: 38,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF888888)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFileButton(String text, VoidCallback onPressed, bool hasFile) {
    return Container(
      width: 260,
      height: 38,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasFile ? const Color(0xFF555555) : const Color(0xFF808080),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          hasFile ? 'File Selected' : text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 600,
        height: 300,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Upload to RLS:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    _buildTextField('Title', _titleController),
                    _buildTextField('Artist', _artistController),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    _buildFileButton('Select a media file.', _pickMedia, _mediaPath != null),
                    _buildFileButton('Select a cover file.', _pickCover, _coverPath != null),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 260,
              height: 38,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {
                  if (_mediaPath != null && _coverPath != null) {
                    widget.onUpload(
                      _titleController.text,
                      _artistController.text,
                      _mediaPath!,
                      _coverPath!,
                    );
                  }
                },
                child: const Text(
                  'Upload',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            if (widget.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFFF4444),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
