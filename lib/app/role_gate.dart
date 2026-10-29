import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

/// Protects routes that require administrator access.
///
/// Requirements:
/// 1. The user must be signed in.
/// 2. users/{uid}.role must equal "admin".
/// 3. The Firebase ID token must contain admin: true.
///
/// Firestore Security Rules and trusted backend operations must enforce
/// authorization independently of this widget.
class RoleGate extends StatefulWidget {
  final Widget child;

  const RoleGate({
    super.key,
    required this.child,
  });

  @override
  State<RoleGate> createState() => _RoleGateState();
}

enum _GateStatus {
  checking,
  allowed,
  denied,
  error,
}

class _RoleCheckResult {
  final _GateStatus status;
  final String message;

  const _RoleCheckResult(
    this.status, {
    this.message = '',
  });

  const _RoleCheckResult.checking() : this(_GateStatus.checking);

  const _RoleCheckResult.allowed() : this(_GateStatus.allowed);

  const _RoleCheckResult.denied([String message = ''])
      : this(
          _GateStatus.denied,
          message: message,
        );

  const _RoleCheckResult.error(String message)
      : this(
          _GateStatus.error,
          message: message,
        );
}

class _RoleGateState extends State<RoleGate> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;

  _RoleCheckResult _result = const _RoleCheckResult.checking();

  int _checkGeneration = 0;
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();

    // Listen for sign-in, sign-out and ID-token changes.
    _authSubscription = _auth.idTokenChanges().listen(
      _handleAuthChange,
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _result = const _RoleCheckResult.error(
            'Unable to verify your sign-in session. Please try again.',
          );
        });
      },
    );

    // Check immediately as well, so the gate does not wait unnecessarily
    // for the first stream event.
    _handleAuthChange(_auth.currentUser);
  }

  void _handleAuthChange(User? user) {
    if (!mounted) return;

    if (user == null) {
      _checkGeneration++;

      setState(() {
        _result = const _RoleCheckResult.denied(
          'Please sign in to continue.',
        );
      });

      _scheduleRedirect(AppRoutes.login);
      return;
    }

    _redirectScheduled = false;

    setState(() {
      _result = const _RoleCheckResult.checking();
    });

    _verifyAdmin(user);
  }

  Future<void> _verifyAdmin(User user) async {
    final generation = ++_checkGeneration;

    try {
      // Refresh the token so recently changed claims can be detected.
      final tokenResult = await user.getIdTokenResult(true);

      // The signed-in account may have changed during the request.
      if (!mounted || generation != _checkGeneration) return;

      if (_auth.currentUser?.uid != user.uid) return;

      final hasAdminClaim = tokenResult.claims?['admin'] == true;

      if (!hasAdminClaim) {
        setState(() {
          _result = const _RoleCheckResult.denied(
            'Your account does not have administrator permission.',
          );
        });

        _scheduleRedirect(AppRoutes.home);
        return;
      }

      final profile = await _firestore.collection('users').doc(user.uid).get();

      if (!mounted || generation != _checkGeneration) return;

      if (_auth.currentUser?.uid != user.uid) return;

      if (!profile.exists) {
        setState(() {
          _result = const _RoleCheckResult.denied(
            'Your user profile was not found. Please contact support.',
          );
        });

        _scheduleRedirect(AppRoutes.home);
        return;
      }

      final data = profile.data();
      final role = data?['role']?.toString().trim().toLowerCase();

      if (role != 'admin') {
        setState(() {
          _result = const _RoleCheckResult.denied(
            'Your account is not registered as an administrator.',
          );
        });

        _scheduleRedirect(AppRoutes.home);
        return;
      }

      setState(() {
        _result = const _RoleCheckResult.allowed();
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted || generation != _checkGeneration) return;

      setState(() {
        _result = _RoleCheckResult.error(
          error.code == 'user-disabled'
              ? 'This account has been disabled.'
              : error.message ?? 'Could not verify your sign-in session.',
        );
      });
    } on FirebaseException catch (error) {
      if (!mounted || generation != _checkGeneration) return;

      setState(() {
        _result = _RoleCheckResult.error(
          error.code == 'permission-denied'
              ? 'Access to your administrator profile was denied. '
                  'Please check your account permissions.'
              : 'Could not verify administrator access. '
                  'Check your connection and try again.',
        );
      });
    } catch (_) {
      if (!mounted || generation != _checkGeneration) return;

      setState(() {
        _result = const _RoleCheckResult.error(
          'Something went wrong while verifying administrator access.',
        );
      });
    }
  }

  void _scheduleRedirect(String route) {
    if (_redirectScheduled || !mounted) return;

    _redirectScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        route,
        (route) => false,
      );
    });
  }

  Future<void> _retry() async {
    if (!mounted) return;

    _redirectScheduled = false;

    final user = _auth.currentUser;

    if (user == null) {
      setState(() {
        _result = const _RoleCheckResult.denied(
          'Please sign in to continue.',
        );
      });

      _scheduleRedirect(AppRoutes.login);
      return;
    }

    setState(() {
      _result = const _RoleCheckResult.checking();
    });

    await _verifyAdmin(user);
  }

  Future<void> _signOutAndReturnToLogin() async {
    try {
      await _auth.signOut();

      if (!mounted) return;

      _scheduleRedirect(AppRoutes.login);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _result = const _RoleCheckResult.error(
          'Could not sign out. Please check your connection and try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_result.status) {
      case _GateStatus.checking:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );

      case _GateStatus.allowed:
        return widget.child;

      case _GateStatus.denied:
        return _accessDeniedScreen();

      case _GateStatus.error:
        return _errorScreen();
    }
  }

  Widget _accessDeniedScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Administrator access required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _result.message.isEmpty
                    ? 'Your account cannot access this page.'
                    : _result.message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  _scheduleRedirect(AppRoutes.home);
                },
                child: const Text('Go to home'),
              ),
              TextButton(
                onPressed: _signOutAndReturnToLogin,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to verify access',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _result.message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _retry,
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: _signOutAndReturnToLogin,
                child: const Text('Sign out and return to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _checkGeneration++;
    _authSubscription?.cancel();
    super.dispose();
  }
}
