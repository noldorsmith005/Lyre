import 'package:flutter/material.dart';
import '../../services/server_client.dart';

class MobileLoginSheet extends StatefulWidget {
  final ServerClient serverClient;
  final Function(bool isConnected) onConnectionStateChanged;
  final VoidCallback? onSyncPressed;

  const MobileLoginSheet({
    Key? key,
    required this.serverClient,
    required this.onConnectionStateChanged,
    this.onSyncPressed,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required ServerClient serverClient,
    required Function(bool isConnected) onConnectionStateChanged,
    VoidCallback? onSyncPressed,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: MobileLoginSheet(
          serverClient: serverClient,
          onConnectionStateChanged: onConnectionStateChanged,
          onSyncPressed: onSyncPressed,
        ),
      ),
    );
  }

  @override
  State<MobileLoginSheet> createState() => _MobileLoginSheetState();
}

class _MobileLoginSheetState extends State<MobileLoginSheet> {
  bool _isLogin = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Username and password are required';
        _isLoading = false;
      });
      return;
    }

    try {
      String? err;
      if (_isLogin) {
        err = await widget.serverClient.login(username, password);
      } else {
        err = await widget.serverClient.createAndRegister(username, password);
      }

      if (err != null) {
        setState(() {
          _errorMessage = err;
          _isLoading = false;
        });
      } else {
        widget.onConnectionStateChanged(true);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegistered = widget.serverClient.registered();

    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF555555),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isRegistered ? 'Server Account' : 'Connect to Server',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF888888)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Toggle Tabs
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isLogin = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isLogin ? const Color(0xFFFF0000) : const Color(0xFF222222),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      ),
                      child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isLogin = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_isLogin ? const Color(0xFFFF0000) : const Color(0xFF222222),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      ),
                      child: const Text('Register', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // TextFields
            _buildInput('Username', _usernameController, Icons.person),
            const SizedBox(height: 12),
            _buildInput('Password', _passwordController, Icons.lock, obscure: true),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF4444), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            // Submit Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isLogin ? 'Log In' : 'Register Account',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            if (isRegistered) ...[
              if (widget.onSyncPressed != null) ...[
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF555555)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.sync, color: Colors.white),
                    label: const Text('Sync Playlists from Server', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onSyncPressed!();
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextButton(
                onPressed: () {
                  widget.serverClient.clearRLSConfig();
                  widget.onConnectionStateChanged(false);
                  Navigator.of(context).pop();
                },
                child: const Text('Clear Server Credentials', style: TextStyle(color: Color(0xFF888888))),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String hint, TextEditingController controller, IconData icon, {bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF666666), size: 20),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF666666)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
