import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🧭 User Screens
import 'package:thamizh/screens/user/login_screen.dart';
import 'package:thamizh/screens/user/signup_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/user/pickup_request_screen.dart';
import 'screens/user/track_status_screen.dart';
import 'screens/user/dropoff_points_screen.dart';
import 'screens/user/info_screen.dart';
import 'screens/user/contact_screen.dart';

// 🔒 Admin Screens
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_banner_upload_screen.dart'; // ✅ NEW IMPORT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // 🌐 Web Firebase config
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBXtphQabzIyG_hw617jPZktk71tUOVfwE",
        authDomain: "thamizh-faf1a.firebaseapp.com",
        projectId: "thamizh-faf1a",
        storageBucket: "thamizh-faf1a.appspot.com", // ✅ .com fixed
        messagingSenderId: "419123520013",
        appId: "1:419123520013:web:a10757344d45442de72b44",
      ),
    ).then((value) {
      print("✅ Firebase initialized successfully for Web");
    });
  } else {
    await Firebase.initializeApp().then((value) {
      print("✅ Firebase initialized successfully for Mobile");
    });
  }

  runApp(const EWasteApp());
}

class EWasteApp extends StatelessWidget {
  const EWasteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thamizh E-Waste',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const AuthCheck(),
      routes: {
        // 👥 User Routes
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        '/pickup': (context) => const PickupRequestScreen(),
        '/track': (context) => const TrackStatusScreen(),
        '/dropoff': (context) => const DropoffPointsScreen(),
        '/info': (context) => InfoScreen(),
        '/contact': (context) => ContactScreen(),

        // 🔐 Admin Routes
        '/admin_login': (context) => AdminLoginScreen(),
        '/admin_dashboard': (context) => AdminDashboardScreen(),
        '/upload_banner': (context) => const AdminBannerUploadScreen(), // ✅ NEW SCREEN
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen(); // ✅ Already logged in
        } else {
          return const LoginScreen(); // 🔐 Not logged in
        }
      },
    );
  }
}
