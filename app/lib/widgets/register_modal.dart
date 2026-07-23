import 'dart:ui';
import 'package:flutter/material.dart';

class RegisterModal extends StatefulWidget {
  final Function(bool isLogin, String url, String token, String username) onSubmit;
  final String? errorMessage;

  const RegisterModal({
    Key? key,
    required this.onSubmit,
    this.errorMessage,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required Function(bool isLogin, String url, String token, String username) onSubmit,
    String? errorMessage,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: RegisterModal(onSubmit: onSubmit, errorMessage: errorMessage),
      ),
    );
  }

  @override
  _RegisterModalState createState() => _RegisterModalState();
}

class _RegisterModalState extends State<RegisterModal> {
  bool _isLogin = true;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _usernameController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 600,
        height: 340,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Mode Toggle Tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isLogin = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isLogin ? const Color(0xFFCC0000) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Login to RLS',
                      style: TextStyle(
                        color: _isLogin ? Colors.white : const Color(0xFF888888),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => _isLogin = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isLogin ? const Color(0xFFCC0000) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Register New User',
                      style: TextStyle(
                        color: !_isLogin ? Colors.white : const Color(0xFF888888),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    _buildTextField('Server URL', _urlController),
                    _buildTextField('App Token', _tokenController),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    _buildTextField('Username', _usernameController),
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
                          widget.onSubmit(
                            _isLogin,
                            _urlController.text,
                            _tokenController.text,
                            _usernameController.text,
                          );
                        },
                        child: Text(
                          _isLogin ? 'Login' : 'Register',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
