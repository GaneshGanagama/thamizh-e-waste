import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../routes/app_routes.dart';
import 'dart:io' show Platform;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get uid => _auth.currentUser?.uid;
  bool get isLoggedIn => _auth.currentUser != null;

  // ============================================================
  // USER PROFILE
  // ============================================================

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
          'vendorStatus': 'none',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snap.data() ?? {};

        final updates = <String, dynamic>{};

        if (!data.containsKey('role')) {
          updates['role'] = 'user';
        }

        if (!data.containsKey('vendorStatus')) {
          updates['vendorStatus'] = 'none';
        }

        if (updates.isNotEmpty) {
          await userDoc.update(updates);
        }
      }
    } catch (e) {
      debugPrint('❌ saveUserInfo error: $e');
    }
  }

  // ============================================================
  // GET USER DATA
  // ============================================================

  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    try {
      final snap = await _firestore.collection('users').doc(user.uid).get();

      if (!snap.exists) return null;

      return snap.data();
    } catch (e) {
      debugPrint('❌ getUserData error: $e');
      return null;
    }
  }

  // ============================================================
  // CHECK VENDOR STATUS
  // ============================================================

  Future<String> getVendorStatus() async {
    final user = _auth.currentUser;

    if (user == null) return 'none';

    try {
      final vendorDoc =
          await _firestore.collection('vendors').doc(user.uid).get();

      if (vendorDoc.exists) {
        final data = vendorDoc.data();

        return (data?['status'] ?? 'none').toString().toLowerCase();
      }

      // Check application if vendor hasn't been approved
      final requests = await _firestore
          .collection('vendor_requests')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (requests.docs.isNotEmpty) {
        return (requests.docs.first.data()['status'] ?? 'pending')
            .toString()
            .toLowerCase();
      }

      return 'none';
    } catch (e) {
      debugPrint('❌ getVendorStatus error: $e');
      return 'none';
    }
  }

  // ============================================================
  // CHECK APPROVED VENDOR
  // ============================================================

  Future<bool> isApprovedVendor() async {
    final user = _auth.currentUser;

    if (user == null) return false;

    try {
      final vendorDoc =
          await _firestore.collection('vendors').doc(user.uid).get();

      if (!vendorDoc.exists) return false;

      final data = vendorDoc.data();

      return data?['status'] == 'approved';
    } catch (e) {
      debugPrint('❌ isApprovedVendor error: $e');
      return false;
    }
  }

  // ============================================================
  // GET VENDOR DATA
  // ============================================================

  Future<Map<String, dynamic>?> getVendorData() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    try {
      final snap = await _firestore.collection('vendors').doc(user.uid).get();

      if (!snap.exists) return null;

      return snap.data();
    } catch (e) {
      debugPrint('❌ getVendorData error: $e');
      return null;
    }
  }

  // ============================================================
  // VENDOR LOGIN
  // ============================================================

  Future<String?> loginAsVendor(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = _auth.currentUser;

      if (user == null) {
        return 'Login failed. Please try again.';
      }

      final vendorDoc =
          await _firestore.collection('vendors').doc(user.uid).get();

      if (!vendorDoc.exists) {
        await _auth.signOut();

        return 'This account is not registered as a vendor.';
      }

      final data = vendorDoc.data() ?? {};

      final status = (data['status'] ?? '').toString().toLowerCase();

      if (status != 'approved') {
        await _auth.signOut();

        if (status == 'pending') {
          return 'Your vendor application is still pending approval.';
        }

        if (status == 'rejected') {
          return 'Your vendor application was rejected.';
        }

        return 'Vendor access is not approved.';
      }

      await saveUserInfo(user);

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Vendor login failed';
    } catch (e) {
      debugPrint('❌ loginAsVendor error: $e');
      return 'Vendor login failed. Please try again.';
    }
  }

  // ============================================================
  // USER LOGIN
  // ============================================================

  Future<String?> loginAsUser(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = _auth.currentUser;

      if (user != null) {
        await saveUserInfo(user);
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    } catch (e) {
      return e.toString();
    }
  }

  // ============================================================
  // ADMIN LOGIN
  // ============================================================

  Future<String?> loginAsAdmin(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = _auth.currentUser;

      if (user == null) {
        return 'Login failed.';
      }

      final snap = await _firestore.collection('users').doc(user.uid).get();

      final data = snap.data() ?? {};

      final role = (data['role'] ?? '').toString().toLowerCase();

      if (role != 'admin') {
        await _auth.signOut();

        return 'This account does not have administrator access.';
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Admin login failed';
    } catch (e) {
      return e.toString();
    }
  }

  // ============================================================
  // NORMAL USER REGISTRATION
  // ============================================================

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
          'role': 'user',
          'vendorStatus': 'none',
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

  // ============================================================
  // OLD NAVIGATION
  // ============================================================

  Future<void> navigateByRole(
    BuildContext context, {
    String? nextRoute,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (_) => false,
      );
      return;
    }

    try {
      final snap = await _firestore.collection('users').doc(user.uid).get();

      final data = snap.data() ?? {};

      final role = (data['role'] ?? 'user').toString().toLowerCase();

      String route = AppRoutes.home;

      if (nextRoute != null && nextRoute.isNotEmpty) {
        route = nextRoute;
      } else if (role == 'admin') {
        route = AppRoutes.admin;
      } else {
        // IMPORTANT:
        // Vendor status does NOT automatically redirect here.
        // Normal users always go to User Home.
        route = AppRoutes.home;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (_) => false,
      );
    } catch (e) {
      debugPrint('❌ navigateByRole error: $e');

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (_) => false,
      );
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

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

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  Future<String?> loginWithGoogle() async {
    try {
      UserCredential credential;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();

        googleProvider.addScope('email');
        googleProvider.addScope(
          'https://www.googleapis.com/auth/userinfo.profile',
        );

        credential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn =
            GoogleSignIn(scopes: ['email', 'profile']);

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          return 'Google sign-in cancelled';
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        credential = await _auth.signInWithCredential(oauthCredential);
      }

      final user = credential.user;

      if (user != null) {
        await saveUserInfo(user);
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Google sign-in failed';
    } catch (e) {
      debugPrint('❌ loginWithGoogle error: $e');
      return e.toString();
    }
  }

  // ============================================================
  // OTP
  // ============================================================

  Future<String?> sendOTP(
    String phone,
    void Function(String verId) onCodeSent,
  ) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential cred) async {
          await _auth.signInWithCredential(cred);

          final user = _auth.currentUser;

          if (user != null) {
            await saveUserInfo(user);
          }
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

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<String?> verifyOTP(
    String verificationId,
    String smsCode,
  ) async {
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCred = await _auth.signInWithCredential(cred);

      final user = userCred.user;

      if (user != null) {
        await saveUserInfo(user);
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'OTP verification failed';
    } catch (e) {
      return e.toString();
    }
  }

  // ============================================================
  // BIOMETRICS
  // ============================================================

  Future<bool> canUseBiometrics() async =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<bool> biometricLogin() async => true;

  // ============================================================
  // SIGN OUT
  // ============================================================

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
