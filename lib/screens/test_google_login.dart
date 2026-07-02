import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class TestGoogleLoginScreen extends StatefulWidget {
  const TestGoogleLoginScreen({super.key});

  @override
  State<TestGoogleLoginScreen> createState() => _TestGoogleLoginScreenState();
}

class _TestGoogleLoginScreenState extends State<TestGoogleLoginScreen> {
  final AuthService _authService = AuthService();
  bool _loading = false;
  String _status = 'Not logged in';

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _loading = true;
      _status = 'Signing in...';
    });

    final result = await _authService.loginWithGoogle();
    setState(() {
      _loading = false;
      _status = result == null ? '✅ Logged in successfully' : '❌ $result';
    });
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    setState(() {
      _status = 'Logged out';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Login Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_status, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              if (_loading)
                const CircularProgressIndicator()
              else ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  onPressed: _handleGoogleLogin,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  onPressed: _handleLogout,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
