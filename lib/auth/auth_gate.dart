import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../routes/app_routes.dart';

/// Authentication and profile service for ECOMEEL.
///
/// Security notes:
/// - Public registration always creates a normal user.
/// - Vendor access requires an approved vendors/{uid} document.
/// - Admin access requires both users/{uid}.role == "admin" and the
///   Firebase ID-token custom claim admin == true.
/// - Firestore Rules / trusted backend code must independently enforce access.
/// - This service never grants admin claims; claims must be set by a trusted
///   server using the Firebase Admin SDK.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String? get uid => _auth.currentUser?.uid;
  bool get isLoggedIn => _auth.currentUser != null;
  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _vendors =>
      _firestore.collection('vendors');

  CollectionReference<Map<String, dynamic>> get _vendorRequests =>
      _firestore.collection('vendor_requests');

  String _normaliseRole(Object? value) =>
      (value ?? '').toString().trim().toLowerCase();

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'popup-closed-by-user':
        return 'The sign-in window was closed before sign-in completed.';
      case 'popup-blocked':
        return 'Your browser blocked the sign-in window. Allow pop-ups and try again.';
      case 'invalid-verification-code':
        return 'The verification code is incorrect.';
      case 'session-expired':
        return 'The verification code expired. Request a new code.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // USER PROFILE
  // ---------------------------------------------------------------------------

  /// Creates a basic profile only if it does not exist.
  ///
  /// Existing roles are never overwritten. New public profiles always receive
  /// role "user", even if a caller supplies a different role for compatibility.
  /// Errors are deliberately rethrown so callers can show a recoverable error.
  Future<void> saveUserInfo(
    User user, {
    String role = 'user',
  }) async {
    final userDoc = _users.doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'name': (user.displayName ?? '').trim(),
        'email': (user.email ?? '').trim().toLowerCase(),
        'phone': user.phoneNumber ?? '',
        'role': 'user',
        'vendorStatus': 'none',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final updates = <String, dynamic>{};

    // Do not overwrite an existing role. If a legacy profile has no role,
    // default it to a normal user, never to a privileged role.
    if (!data.containsKey('role') || data['role'] == null) {
      updates['role'] = 'user';
    }
    if (!data.containsKey('vendorStatus')) {
      updates['vendorStatus'] = 'none';
    }
    if ((data['uid'] ?? '').toString().isEmpty) {
      updates['uid'] = user.uid;
    }
    if ((data['email'] ?? '').toString().isEmpty && user.email != null) {
      updates['email'] = user.email!.trim().toLowerCase();
    }
    if ((data['name'] ?? '').toString().isEmpty &&
        (user.displayName ?? '').trim().isNotEmpty) {
      updates['name'] = user.displayName!.trim();
    }
    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await userDoc.update(updates);
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _users.doc(user.uid).get();
    if (!snapshot.exists) return null;
    return snapshot.data();
  }

  // ---------------------------------------------------------------------------
  // VENDOR STATUS / PROFILE
  // ---------------------------------------------------------------------------

  /// Returns approved/pending/rejected/none, or "error" if the status could
  /// not be verified. "error" is intentionally distinct from "none".
  Future<String> getVendorStatus() async {
    final user = _auth.currentUser;
    if (user == null) return 'none';

    try {
      final vendorDoc = await _vendors.doc(user.uid).get();
      if (vendorDoc.exists) {
        return _normaliseRole(vendorDoc.data()?['status']).isEmpty
            ? 'unknown'
            : _normaliseRole(vendorDoc.data()?['status']);
      }

      final requests = await _vendorRequests
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (requests.docs.isEmpty) return 'none';
      final status = _normaliseRole(requests.docs.first.data()['status']);
      return status.isEmpty ? 'pending' : status;
    } on FirebaseException catch (error) {
      debugPrint('getVendorStatus failed (${error.code}).');
      return 'error';
    } catch (error) {
      debugPrint('getVendorStatus failed: $error');
      return 'error';
    }
  }

  Future<bool> isApprovedVendor() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await _vendors.doc(user.uid).get();
      return snapshot.exists &&
          _normaliseRole(snapshot.data()?['status']) == 'approved' &&
          (snapshot.data()?['userId'] ?? user.uid).toString() == user.uid;
    } catch (error) {
      debugPrint('isApprovedVendor failed: $error');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getVendorData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _vendors.doc(user.uid).get();
    if (!snapshot.exists) return null;
    return snapshot.data();
  }

  // ---------------------------------------------------------------------------
  // EMAIL/PASSWORD LOGIN
  // ---------------------------------------------------------------------------

  Future<String?> loginAsVendor(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return 'Login failed. Please try again.';

      final vendorDoc = await _vendors.doc(user.uid).get();
      if (!vendorDoc.exists) {
        await _safeSignOut();
        return 'This account does not have a vendor application or approved vendor profile.';
      }

      final data = vendorDoc.data() ?? <String, dynamic>{};
      final status = _normaliseRole(data['status']);

      if ((data['userId'] ?? user.uid).toString() != user.uid) {
        await _safeSignOut();
        return 'Vendor account details could not be verified. Contact support.';
      }
      if (status != 'approved') {
        await _safeSignOut();
        if (status == 'pending') {
          return 'Your vendor application is waiting for admin approval.';
        }
        if (status == 'rejected') {
          return 'Your vendor application was rejected. Contact support for details.';
        }
        if (status == 'suspended') {
          return 'Your vendor account is suspended. Contact support.';
        }
        return 'Vendor access is not approved.';
      }

      // Do not let a failed profile write silently look like a successful login.
      await saveUserInfo(user);
      return null;
    } on FirebaseAuthException catch (error) {
      return _friendlyAuthError(error);
    } on FirebaseException catch (error) {
      debugPrint('loginAsVendor Firestore error (${error.code}).');
      await _safeSignOut();
      return error.code == 'permission-denied'
          ? 'Could not verify vendor access. Please contact support.'
          : 'Could not verify your vendor account. Check your connection and try again.';
    } catch (error) {
      debugPrint('loginAsVendor failed: $error');
      await _safeSignOut();
      return 'Vendor login failed. Please try again.';
    }
  }

  Future<String?> loginAsUser(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return 'Login failed. Please try again.';

      await saveUserInfo(user);
      final profile = await _users.doc(user.uid).get();
      final role = _normaliseRole(profile.data()?['role']);

      // Keep admin/vendor accounts from accidentally using the customer login.
      if (role == 'admin') {
        await _safeSignOut();
        return 'This is an administrator account. Select Admin login.';
      }
      if (role == 'vendor') {
        await _safeSignOut();
        return 'This is a vendor account. Select Vendor login.';
      }
      return null;
    } on FirebaseAuthException catch (error) {
      return _friendlyAuthError(error);
    } on FirebaseException catch (error) {
      debugPrint('loginAsUser Firestore error (${error.code}).');
      await _safeSignOut();
      return 'Signed in, but your profile could not be verified. Please try again.';
    } catch (error) {
      debugPrint('loginAsUser failed: $error');
      await _safeSignOut();
      return 'Login failed. Please try again.';
    }
  }

  Future<String?> loginAsAdmin(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return 'Login failed. Please try again.';

      final token = await user.getIdTokenResult(true);
      final hasAdminClaim = token.claims?['admin'] == true;
      final snapshot = await _users.doc(user.uid).get();
      final role = _normaliseRole(snapshot.data()?['role']);

      if (!snapshot.exists || role != 'admin' || !hasAdminClaim) {
        await _safeSignOut();
        return 'Administrator access is not configured for this account. Contact the system administrator.';
      }

      return null;
    } on FirebaseAuthException catch (error) {
      return _friendlyAuthError(error);
    } on FirebaseException catch (error) {
      debugPrint('loginAsAdmin Firestore error (${error.code}).');
      await _safeSignOut();
      return 'Could not verify administrator access. Check your connection and try again.';
    } catch (error) {
      debugPrint('loginAsAdmin failed: $error');
      await _safeSignOut();
      return 'Administrator login failed. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // NORMAL USER REGISTRATION
  // ---------------------------------------------------------------------------

  /// Public registration can only create a normal user account.
  /// The role parameter is intentionally not accepted here.
  Future<String?> registerUser({
    required String email,
    required String password,
    required String name,
    // Kept for compatibility with existing callers. Public registration
    // intentionally ignores this value and always creates role "user".
    String role = 'user',
  }) async {
    try {
      final cleanName = name.trim();
      final cleanEmail = email.trim().toLowerCase();

      if (cleanName.isEmpty) return 'Enter your name.';
      if (cleanEmail.isEmpty) return 'Enter your email address.';
      if (password.length < 6) return 'Password must be at least 6 characters.';

      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) return 'Account creation failed. Please try again.';

      await user.updateDisplayName(cleanName);
      await _users.doc(user.uid).set({
        'uid': user.uid,
        'name': cleanName,
        'email': cleanEmail,
        'phone': user.phoneNumber ?? '',
        'role': 'user',
        'vendorStatus': 'none',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (error) {
      return _friendlyAuthError(error);
    } on FirebaseException catch (error) {
      debugPrint('registerUser Firestore error (${error.code}).');
      // The Auth account may already exist. Keep the session so the user can
      // retry profile creation rather than pretending registration succeeded.
      return 'Your account was created, but your profile could not be saved. '
          'Please sign in again or contact support.';
    } catch (error) {
      debugPrint('registerUser failed: $error');
      return 'Signup failed. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // ROLE-BASED NAVIGATION
  // ---------------------------------------------------------------------------

  Future<void> navigateByRole(
    BuildContext context, {
    String? nextRoute,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
      return;
    }

    String route = AppRoutes.home;

    try {
      final snapshot = await _users.doc(user.uid).get();
      if (!context.mounted) return;

      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your profile is not ready. Please try again.'),
          ),
        );
        return;
      }

      final role = _normaliseRole(snapshot.data()?['role']);

      if (role == 'admin') {
        final token = await user.getIdTokenResult(true);
        if (token.claims?['admin'] != true) {
          await _safeSignOut();
          if (!context.mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.login,
            (route) => false,
          );
          return;
        }
        route = AppRoutes.admin;
      } else if (role == 'vendor') {
        if (await isApprovedVendor()) {
          // Use the existing route constant if the project defines it.
          route = AppRoutes.vendorDashboard;
        } else {
          route = AppRoutes.home;
        }
      } else {
        route = AppRoutes.home;
      }

      // A caller-supplied route is not an authorization mechanism. Protected
      // destination screens must still have their own guards.
      if (nextRoute != null && nextRoute.trim().isNotEmpty) {
        route = nextRoute.trim();
      }

      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        route,
        (route) => false,
      );
    } on FirebaseException catch (error) {
      debugPrint('navigateByRole Firestore error (${error.code}).');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not verify your account. Check your connection and retry.'),
        ),
      );
    } catch (error) {
      debugPrint('navigateByRole failed: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open your account. Please try again.'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PASSWORD RESET
  // ---------------------------------------------------------------------------

  Future<String?> forgotPassword(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return 'Enter your email address.';

    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
      return null;
    } on FirebaseAuthException catch (error) {
      return _friendlyAuthError(error);
    } catch (error) {
      debugPrint('forgotPassword failed: $error');
      return 'Could not send the reset email. Check your connection and try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // GOOGLE SIGN-IN
  // ---------------------------------------------------------------------------

  Future<String?> loginWithGoogle() async {
    try {
      UserCredential credential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');

        credential = await _auth.signInWithPopup(provider);
      } else {
        final googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
        );
        final googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          return 'Google sign-in was cancelled.';
        }

        final googleAuth = await googleUser.authentication;
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        credential = await _auth.signInWithCredential(oauthCredential);
      }

      final user = credential.user;
      if (user == null) return 'Google sign-in failed. Please try again.';

      await saveUserInfo(user);
      return null;
    } on FirebaseAuthException catch (error) {
      return _friendlyAuthError(error);
    } on FirebaseException catch (error) {
      debugPrint('loginWithGoogle Firestore error (${error.code}).');
      await _safeSignOut();
      return 'Signed in, but your profile could not be verified. Please try again.';
    } catch (error) {
      debugPrint('loginWithGoogle failed: $error');
      return 'Google sign-in failed. Check your connection and try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // PHONE OTP
  // ---------------------------------------------------------------------------

  Future<String?> sendOTP(
    String phone,
    void Function(String verificationId) onCodeSent, {
    void Function(String message)? onError,
    int? forceResendingToken,
  }) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty || !cleanPhone.startsWith('+')) {
      return 'Enter a valid phone number including country code, for example +91XXXXXXXXXX.';
    }

    final completer = Completer<String?>();
    var callbackCompleted = false;

    void finish(String? error) {
      if (!completer.isCompleted) completer.complete(error);
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: cleanPhone,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final result = await _auth.signInWithCredential(credential);
            final user = result.user;
            if (user != null) await saveUserInfo(user);
          } catch (error) {
            debugPrint('Automatic phone verification failed: $error');
            onError?.call('Automatic verification failed. Enter the SMS code.');
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          final message = _friendlyAuthError(error);
          onError?.call(message);
          finish(message);
        },
        codeSent: (String verificationId, int? resendToken) {
          callbackCompleted = true;
          onCodeSent(verificationId);
          finish(null);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // The ID can still be used to verify a manually entered SMS code.
        },
      );

      // Some platforms return before the callbacks fire. Do not wait forever.
      if (!callbackCompleted && !completer.isCompleted) {
        return null;
      }
      return await completer.future;
    } on FirebaseAuthException catch (error) {
      final message = _friendlyAuthError(error);
      onError?.call(message);
      return message;
    } catch (error) {
      debugPrint('sendOTP failed: $error');
      const message = 'Phone verification failed. Please try again.';
      onError?.call(message);
      return message;
    }
  }

  Future<String?> verifyOTP(
    String verificationId,
    String smsCode,
  ) async {
    if (verificationId.trim().isEmpty) {
      return 'Request a new verification code and try again.';
    }
    if (smsCode.trim().isEmpty) return 'Enter the verification code.';

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) return 'Phone verification failed. Please try again.';

      await saveUserInfo(user);
      return null;
    } on FirebaseAuthException catch (error) {
      return _friendlyAuthError(error);
    } on FirebaseException catch (error) {
      debugPrint('verifyOTP Firestore error (${error.code}).');
      return 'Your phone was verified, but your profile could not be saved.';
    } catch (error) {
      debugPrint('verifyOTP failed: $error');
      return 'OTP verification failed. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // BIOMETRICS
  // ---------------------------------------------------------------------------

  Future<bool> canUseBiometrics() async {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Biometrics are not implemented in this service. Do not report success
  /// until a local_auth flow has actually verified the user.
  Future<bool> biometricLogin() async => false;

  // ---------------------------------------------------------------------------
  // SIGN OUT
  // ---------------------------------------------------------------------------

  Future<void> _safeSignOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      debugPrint('Firebase sign-out failed: $error');
    }
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (error) {
        debugPrint('Google sign-out failed: $error');
      }
    }
  }

  Future<void> signOut() async {
    await _safeSignOut();
  }
}
