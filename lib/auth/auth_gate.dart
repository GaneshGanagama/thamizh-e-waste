import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../routes/app_routes.dart'; // ✅ fixed import
import 'dart:io' show Platform;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  bool get isLoggedIn => _auth.currentUser != null;

  // ---------------- Save User Info ----------------
  Future<void> saveUserInfo(User user, {String role = 'user'}) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final snap = await userDoc.get();
      if (!snap.exists) {
        await userDoc.set({
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snap.data() ?? {};
        if (!data.containsKey('role')) {
          await userDoc.update({'role': role});
        }
      }
    } catch (e) {
      debugPrint('❌ saveUserInfo error: $e');
    }
  }

  // ---------------- Navigation ----------------
  Future<void> navigateByRole(BuildContext context, {String? nextRoute}) async {
    final user = _auth.currentUser;
    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      return;
    }

    try {
      final snap = await _firestore.collection('users').doc(user.uid).get();
      final role = (snap.data()?['role'] ?? 'user').toString().toLowerCase();

      String route = AppRoutes.home;
      if (nextRoute != null && nextRoute.isNotEmpty) {
        route = nextRoute;
      } else if (role == 'admin') {
        route = AppRoutes.admin;
      } else if (role == 'vendor') {
        route = AppRoutes.vendorDashboard;
      }

      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
    } catch (e) {
      debugPrint('❌ navigateByRole error: $e');
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    }
  }

  // ---------------- Email / Password ----------------
  Future<String?> loginWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = _auth.currentUser;
      if (user != null) await saveUserInfo(user);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> registerUser({
    required String email,
    required String password,
    required String name,
    String role = 'user',
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Signup failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to send reset email';
    } catch (e) {
      return e.toString();
    }
  }

  // ---------------- Google Sign-In ----------------
  Future<String?> loginWithGoogle() async {
    try {
      UserCredential credential;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider
            .addScope('https://www.googleapis.com/auth/userinfo.profile');
        credential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn =
            GoogleSignIn(scopes: ['email', 'profile']);

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return 'Google sign-in cancelled';

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        credential = await _auth.signInWithCredential(oauthCredential);
      }

      final user = credential.user;
      if (user != null) await saveUserInfo(user);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Google sign-in failed';
    } catch (e) {
      debugPrint('❌ loginWithGoogle error: $e');
      return e.toString();
    }
  }

  // ---------------- OTP (Phone Auth) ----------------
  Future<String?> sendOTP(
      String phone, void Function(String verId) onCodeSent) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential cred) async {
          await _auth.signInWithCredential(cred);
          final user = _auth.currentUser;
          if (user != null) await saveUserInfo(user);
        },
        verificationFailed: (FirebaseAuthException e) {
          throw e;
        },
        codeSent: (String verId, int? resendToken) {
          onCodeSent(verId);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Phone verification failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> verifyOTP(String verificationId, String smsCode) async {
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCred = await _auth.signInWithCredential(cred);
      final user = userCred.user;
      if (user != null) await saveUserInfo(user);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'OTP verification failed';
    } catch (e) {
      return e.toString();
    }
  }

  // ---------------- Biometrics ----------------
  Future<bool> canUseBiometrics() async =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> biometricLogin() async => true;

  // ---------------- Sign Out ----------------
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        GoogleSignIn().signOut(),
      ]);
    } catch (e) {
      debugPrint('❌ SignOut error: $e');
    }
  }
}
