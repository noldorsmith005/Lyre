import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/media_handler.dart';
import '../services/server_client.dart';
import '../services/theme_service.dart';
import '../utils/platform_utils.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'mobile/mobile_home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final MediaHandler? mediaHandler;
  final ServerClient serverClient;
  final VoidCallback? onRegisterSuccess;

  const RegisterScreen({
    Key? key,
    this.mediaHandler,
    required this.serverClient,
    this.onRegisterSuccess,
  }) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill out all fields.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    if (password.length < 4) {
      setState(() {
        _errorMessage = 'Password must be at least 4 characters long.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final err = await widget.serverClient.createAndRegister(username, password);
      if (!mounted) return;

      if (err != null) {
        setState(() {
          _isLoading = false;
          _errorMessage = err;
        });
      } else {
        if (widget.onRegisterSuccess != null) {
          widget.onRegisterSuccess!();
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else if (widget.mediaHandler != null) {
          _navigateToHome();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToHome() {
    if (widget.mediaHandler == null) return;
    final Widget homeScreen = isDesktop
        ? HomeScreen(
            mediaHandler: widget.mediaHandler!,
            serverClient: widget.serverClient,
          )
        : MobileHomeScreen(
            mediaHandler: widget.mediaHandler!,
            serverClient: widget.serverClient,
            appDataPath: widget.mediaHandler!.appDataPath,
          );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => homeScreen),
    );
  }

  void _navigateToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            mediaHandler: widget.mediaHandler,
            serverClient: widget.serverClient,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<ThemeService>().themeColor;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon / Logo
                Center(
                  child: Icon(
                    Icons.person_add_rounded,
                    size: 64,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Heading
                const Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign up to sync your music and playlists across devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 32),

                // Username Input
                _buildInput(
                  hint: 'Username',
                  controller: _usernameController,
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),

                // Password Input
                _buildInput(
                  hint: 'Password',
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF888888),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm Password Input
                _buildInput(
                  hint: 'Confirm Password',
                  controller: _confirmPasswordController,
                  icon: Icons.lock_reset_outlined,
                  obscure: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF888888),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                const SizedBox(height: 20),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A1010),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF4444)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFFF4444), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Submit Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Register Account',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Toggle Link to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: _navigateToLogin,
                      child: Text(
                        'Log In',
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF666666), size: 20),
          suffixIcon: suffixIcon,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF666666)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
