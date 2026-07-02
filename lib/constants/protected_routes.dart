// lib/constants/protected_routes.dart
// ------------------------------------------------------------
// Production-Ready ProtectedRoute
// Redirects unauthenticated users to LoginScreen, and passes
// the intended route so that after login user returns safely.
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';

class ProtectedRoute extends StatelessWidget {
  final Widget child;
  final String? nextRoute; // route to return to after login

  const ProtectedRoute({
    super.key,
    required this.child,
    this.nextRoute,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 🛑 User NOT logged in → redirect to login
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
          arguments: {
            'nextRoute': nextRoute,
          },
        );
      });

      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ✔ User logged in → allow access
    return child;
  }
}
