import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

class ProtectedRoute extends StatefulWidget {
  final Widget child;

  /// Route to open after successful login.
  final String? nextRoute;

  /// Supported values: null, 'user', 'vendor', 'admin'.
  /// Set this explicitly for vendor and admin routes.
  final String? requiredRole;

  const ProtectedRoute({
    super.key,
    required this.child,
    this.nextRoute,
    this.requiredRole,
  });

  @override
  State<ProtectedRoute> createState() => _ProtectedRouteState();
}

class _ProtectedRouteState extends State<ProtectedRoute> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;

  User? _user;
  bool _checking = true;
  bool _redirectScheduled = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _user = _auth.currentUser;
    _authSubscription = _auth.authStateChanges().listen(
      (user) {
        if (!mounted) return;

        setState(() {
          _user = user;
          _checking = true;
          _error = null;
          _redirectScheduled = false;
        });

        _checkAccess(user);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _error = 'Could not verify your login. Please try again.';
        });
      },
    );

    _checkAccess(_user);
  }

  Future<void> _checkAccess(User? user) async {
    if (user == null) {
      if (!mounted) return;
      setState(() => _checking = false);
      _redirectToLogin();
      return;
    }

    final role = widget.requiredRole?.toLowerCase();

    if (role == null || role == 'user') {
      if (!mounted) return;
      setState(() => _checking = false);
      return;
    }

    if (role != 'vendor' && role != 'admin') {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'This page has an invalid access configuration.';
      });
      return;
    }

    try {
      bool allowed = false;

      if (role == 'admin') {
        final token = await user.getIdTokenResult(true);
        final claims = token.claims ?? {};

        final profile =
            await _firestore.collection('users').doc(user.uid).get();

        allowed = claims['admin'] == true &&
            profile.data()?['role']?.toString().toLowerCase() == 'admin';
      } else {
        final vendorDoc =
            await _firestore.collection('vendors').doc(user.uid).get();

        if (vendorDoc.exists) {
          final data = vendorDoc.data()!;
          final linkedUid = data['userId']?.toString();

          allowed = data['status']?.toString().toLowerCase() == 'approved' &&
              (linkedUid == null || linkedUid == user.uid);
        }
      }

      if (!mounted || _auth.currentUser?.uid != user.uid) return;

      setState(() {
        _checking = false;
        _error =
            allowed ? null : 'You do not have permission to access this page.';
      });

      if (!allowed) {
        _redirectToHome();
      }
    } on FirebaseAuthException {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Could not verify your account. Please sign in again.';
      });
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error =
            'Could not verify access. Check your connection or permissions.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'An unexpected error occurred while checking access.';
      });
    }
  }

  void _redirectToLogin() {
    if (_redirectScheduled || !mounted) return;
    _redirectScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _auth.currentUser != null) return;

      final currentRoute = ModalRoute.of(context)?.settings.name;
      final destination = widget.nextRoute ?? currentRoute;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (_) => false,
        arguments: <String, String?>{
          'nextRoute': destination,
        },
      );
    });
  }

  void _redirectToHome() {
    if (_redirectScheduled || !mounted) return;
    _redirectScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_user == null || _error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Colors.blueGrey,
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Please sign in to continue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_user == null) {
                      _redirectToLogin();
                    } else {
                      _checkAccess(_user);
                    }
                  },
                  child: Text(
                    _user == null ? 'Go to Login' : 'Try Again',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
