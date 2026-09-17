// lib/routes/app_routes.dart
// ---------------------------------------------------------------
// FINAL PRODUCTION VERSION
// ---------------------------------------------------------------

import 'package:flutter/material.dart';

// Guards
import '../constants/protected_routes.dart';
import '../app/role_gate.dart';

// User screens
import '../screens/user/login_screen.dart';
import '../screens/user/signup_screen.dart';
import '../screens/user/home_screen.dart';
import '../screens/user/profile_screen.dart';
import '../screens/user/pickup_request_screen.dart';
import '../screens/user/privacy_policy_screen.dart';
import '../screens/user/rewards_screen.dart';
import '../screens/user/donate_e_waste_screen.dart';
import '../screens/user/contact_screen.dart';
import '../screens/user/track_status_screen.dart';
import '../screens/user/vendor_list_screen.dart';
import '../screens/user/vendor_registration_screen.dart';
import '../screens/user/certificates_screen.dart';
import '../screens/user/dropoff_points_screen.dart';
import '../screens/user/reviews_screen.dart';
import '../screens/user/refurbished_screen.dart';
import '../screens/user/user_awareness_screen.dart';

// Vendor screens
import '../screens/vendor/vendor_dashboard_screen.dart';
import '../screens/vendor/vendor_assigned_pickups_screen.dart';
import '../screens/vendor/vendor_dropoff_requests_screen.dart';
import '../screens/vendor/vendor_profile_screen.dart';

// Admin screens
import '../screens/admin/admindashboard_screen.dart';
import '../screens/admin/requests_tab.dart';
import '../screens/admin/awareness_tab.dart';
import '../screens/admin/banners_tab.dart';

/// ---------------------------------------------------------------
/// Route Name Constants
/// ---------------------------------------------------------------
class AppRoutes {
  // Public
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String contact = '/contact';
  static const String privacy = '/privacy';

  // User Protected
  static const String profile = '/profile';
  static const String pickup = '/pickup';
  static const String rewards = '/rewards';
  static const String donate = '/donate';
  static const String dropoff = '/dropoff';
  static const String certificates = '/certificates';
  static const String track = '/track';
  static const String refurbished = '/refurbished';
  static const String reviews = '/reviews';
  static const String userAwareness = '/user-awareness';

  // Vendor registration (protected)
  static const String vendorList = '/vendor-list';
  static const String vendorRegister = '/vendor-register';

  // Vendor dashboard screens (protected)
  static const String vendorDashboard = '/vendor-dashboard';
  static const String vendorPickups = '/vendor-pickups';
  static const String vendorDropoff = '/vendor-dropoff';
  static const String vendorProfile = '/vendor-profile';

  // Admin (role-gated)
  static const String admin = '/admin';
  static const String requests = '/requests';
  static const String banners = '/banners';
  static const String awareness = '/awareness';
}

/// ---------------------------------------------------------------
/// Route Map
/// ---------------------------------------------------------------
final Map<String, WidgetBuilder> appRoutes = {
  // ── Public ──────────────────────────────────────────────────────────────
  AppRoutes.login: (_) => const LoginScreen(),
  AppRoutes.signup: (_) => const SignUpScreen(),

  // showLoginButton=true → Login button always visible for guests
  AppRoutes.home: (_) => const HomeScreen(
        isVendor: false,
        showLoginButton: true,
      ),

  AppRoutes.contact: (_) => const ContactScreen(),
  AppRoutes.privacy: (_) => const PrivacyPolicyScreen(),
  AppRoutes.vendorList: (_) => const VendorListScreen(),
  AppRoutes.track: (_) => const TrackStatusScreen(),
  AppRoutes.reviews: (_) => const ReviewsScreen(),
  AppRoutes.refurbished: (_) => const RefurbishedScreen(),
  AppRoutes.userAwareness: (_) => const UserAwarenessScreen(),

  // ── User Protected ───────────────────────────────────────────────────────
  AppRoutes.profile: (_) => ProtectedRoute(
        child: const ProfileScreen(),
        nextRoute: AppRoutes.profile,
      ),

  AppRoutes.pickup: (_) => ProtectedRoute(
        child: const PickupRequestScreen(),
        nextRoute: AppRoutes.pickup,
      ),

  AppRoutes.donate: (_) => ProtectedRoute(
        child: const DonateEWasteScreen(),
        nextRoute: AppRoutes.donate,
      ),

  AppRoutes.dropoff: (_) => ProtectedRoute(
        child: const DropoffPointsScreen(),
        nextRoute: AppRoutes.dropoff,
      ),

  AppRoutes.vendorRegister: (_) => ProtectedRoute(
        child: const VendorRegistrationScreen(),
        nextRoute: AppRoutes.vendorRegister,
      ),

  AppRoutes.rewards: (_) => ProtectedRoute(
        child: const RewardsScreen(),
        nextRoute: AppRoutes.rewards,
      ),

  AppRoutes.certificates: (_) => ProtectedRoute(
        child: const CertificatesScreen(),
        nextRoute: AppRoutes.certificates,
      ),

  // ── Vendor ───────────────────────────────────────────────────────────────
  AppRoutes.vendorDashboard: (_) => ProtectedRoute(
        child: const VendorDashboardScreen(),
        nextRoute: AppRoutes.vendorDashboard,
      ),

  AppRoutes.vendorPickups: (_) => ProtectedRoute(
        child: const VendorAssignedPickupsScreen(),
        nextRoute: AppRoutes.vendorPickups,
      ),

  AppRoutes.vendorDropoff: (_) => ProtectedRoute(
        child: const VendorDropoffRequestsScreen(),
        nextRoute: AppRoutes.vendorDropoff,
      ),

  AppRoutes.vendorProfile: (_) => ProtectedRoute(
        child: const VendorProfileScreen(),
        nextRoute: AppRoutes.vendorProfile,
      ),

  // ── Admin (role-gated) ────────────────────────────────────────────────────
  AppRoutes.admin: (_) => RoleGate(child: const AdminDashboardScreen()),
  AppRoutes.requests: (_) => RoleGate(child: const RequestsTab()),
  AppRoutes.banners: (_) => RoleGate(child: const BannersTab()),
  AppRoutes.awareness: (_) => RoleGate(child: const AwarenessTab()),
};
