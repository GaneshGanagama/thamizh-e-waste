import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade100,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to E-Waste App',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: Text('Login'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
