// lib/screens/user/signup_screen.dart
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../routes/app_routes.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}
class _SignUpScreenState extends State<SignUpScreen> {
  final _auth = AuthService();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _confCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) { _snack('Enter your name'); return; }
    if (_emailCtrl.text.trim().isEmpty) { _snack('Enter your email'); return; }
    if (_passCtrl.text.length < 6) { _snack('Password must be at least 6 characters'); return; }
    if (_passCtrl.text != _confCtrl.text) { _snack('Passwords do not match'); return; }
    setState(() => _loading = true);
    final err = await _auth.registerUser(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      name: _nameCtrl.text.trim(),
    );
    setState(() => _loading = false);
    if (err == null) {
      await _auth.navigateByRole(context);
    } else {
      _snack(err);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 16),
          Icon(Icons.person_add, size: 56, color: Colors.green[700]),
          const SizedBox(height: 24),
          _field(_nameCtrl,  'Full Name',     Icons.person),
          const SizedBox(height: 14),
          _field(_emailCtrl, 'Email',         Icons.email, type: TextInputType.emailAddress),
          const SizedBox(height: 14),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: const OutlineInputBorder(),
              filled: true, fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          _field(_confCtrl, 'Confirm Password', Icons.lock_outline, obscure: true),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700], foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
            child: Text('Already have an account? Login', style: TextStyle(color: Colors.green[700])),
          ),
        ]),
      )),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType type = TextInputType.text, bool obscure = false}) =>
      TextField(
        controller: c, keyboardType: type, obscureText: obscure,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon),
          border: const OutlineInputBorder(), filled: true, fillColor: Colors.white,
        ),
      );
}
