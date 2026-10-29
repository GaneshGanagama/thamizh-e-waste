import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../routes/app_routes.dart';

/// Checks whether the user is logged in.
///
/// If logged in, runs [onSuccess].
/// If not logged in, opens the login screen and passes the intended
/// destination so the user can return there after a successful login.
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
    arguments: <String, String?>{
      'nextRoute': nextRoute,
    },
  );
}
