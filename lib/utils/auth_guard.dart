// lib/utils/auth_guard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';

/// Checks if user is logged in.
/// If yes, calls [onSuccess].
/// If no, navigates to LoginScreen with a nextRoute argument so the user
/// is redirected back after login.
void requireLogin(
  BuildContext context, {
  required VoidCallback onSuccess,
  String? nextRoute,
}) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    onSuccess();
    return;
  }

  Navigator.pushNamed(
    context,
    AppRoutes.login,
    arguments: nextRoute,
  );
}
