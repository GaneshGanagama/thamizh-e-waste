import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final otpController = TextEditingController(); // For future OTP use

  bool isLoading = false;
  bool useOTP = false;
  bool _obscurePassword = true;

  // ✅ Save User Info to Firestore (if not exists)
  Future<void> saveUserInfo(User user) async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists) {
        await userDoc.set({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'uid': user.uid,
          'role': 'user', // default role for normal users
          'createdAt': Timestamp.now(),
        });
      }
    } catch (e) {
      print("❌ Failed to save user info: $e");
    }
  }

  // ✅ Login with Email & Password
  Future<void> _loginWithEmail() async {
    setState(() => isLoading = true);
    try {
      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text.trim();

      // Firebase Auth Sign-In
      UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await saveUserInfo(user);

        // ✅ Check Firestore for role
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (snapshot.exists) {
          final role = snapshot.data()?['role'] ?? 'user';
          if (role == 'admin') {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/admin_dashboard', (route) => false);
          } else {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/home', (route) => false);
          }
        } else {
          // Default to user home if no role found
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      print("🔥 FirebaseAuthException: ${e.code} - ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: ${e.message}")),
      );
    } catch (e) {
      print("❌ Unexpected error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed: Unexpected error.")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ✅ Build text field widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isObscure = false,
    bool isPasswordField = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPasswordField ? _obscurePassword : isObscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[100],
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: isPasswordField
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30.0, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Thamizh",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildTextField(
                    controller: emailController,
                    label: 'Email',
                    icon: Icons.email,
                  ),
                  const SizedBox(height: 20),
                  useOTP
                      ? _buildTextField(
                          controller: otpController,
                          label: 'Enter OTP',
                          icon: Icons.sms,
                        )
                      : _buildTextField(
                          controller: passwordController,
                          label: 'Password',
                          icon: Icons.lock,
                          isPasswordField: true,
                        ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _loginWithEmail,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.lightGreen[700],
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Login", style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() => useOTP = !useOTP);
                    },
                    child: Text(
                      useOTP
                          ? "Use Email & Password Login"
                          : "Use OTP Login (coming soon)",
                      style: TextStyle(color: Colors.green[800]),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text("Don't have an account? Sign Up"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
