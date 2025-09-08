import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  bool isLoading = false;

  Future<void> _register() async {
    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match.")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      // ✅ Create Firebase Auth User
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        // ✅ Update Auth Profile (Name & Phone)
        await user.updateDisplayName(nameController.text.trim());

        // NOTE: Firebase Auth doesn't directly store phone number in email/password accounts.
        // You can store it separately in Firestore.

        // ✅ Save full profile to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'email': user.email,
          'createdAt': DateTime.now(),
        });
      }

      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup failed: ${e.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup failed: Unexpected error $e.")),
      );
      print(e);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isObscure = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: inputType,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[100],
        labelText: label,
        prefixIcon: Icon(icon),
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
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Thamizh - Sign Up",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 30),
                _buildTextField(
                  controller: nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  inputType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: emailController,
                  label: 'Email',
                  icon: Icons.email,
                  inputType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: passwordController,
                  label: 'Password',
                  icon: Icons.lock,
                  isObscure: true,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: confirmPasswordController,
                  label: 'Confirm Password',
                  icon: Icons.lock_outline,
                  isObscure: true,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.lightGreen[700],
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Sign Up", style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text("Already have an account? Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
