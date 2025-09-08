import 'package:flutter/material.dart';

class AdminLoginScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  AdminLoginScreen({super.key});

  void _adminLogin(BuildContext context) {
    // TODO: Replace with Firebase Auth & role validation
    if (emailController.text == "admin@ewaste.com" &&
        passwordController.text == "admin123") {
      Navigator.pushNamed(context, '/admin_dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid admin credentials")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin Login")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SizedBox(height: 60),
            Icon(Icons.admin_panel_settings, size: 80, color: Colors.green),
            SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Admin Email"),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "Password"),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _adminLogin(context),
              child: Text("Login as Admin"),
            ),
          ],
        ),
      ),
    );
  }
}
