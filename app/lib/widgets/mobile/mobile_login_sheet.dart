import 'package:flutter/material.dart';
import '../../services/server_client.dart';
import '../../screens/login_screen.dart';

/// Legacy mobile sheet wrapper that forwards to the cross-platform LoginScreen
class MobileLoginSheet {
  static void show(
    BuildContext context, {
    required ServerClient serverClient,
    required VoidCallback onLoginSuccess,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          serverClient: serverClient,
          onLoginSuccess: onLoginSuccess,
        ),
      ),
    );
  }
}
