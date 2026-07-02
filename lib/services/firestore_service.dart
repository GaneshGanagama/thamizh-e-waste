// lib/services/firestore_service.dart
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class ServiceItem {
  final IconData icon;
  final String   label;
  final String   route;
  final Color    color;
  const ServiceItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
}

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  List<ServiceItem> servicesList(bool isVendor, String language) {
    if (isVendor) {
      return [
        ServiceItem(icon: Icons.dashboard,      label: 'Dashboard',       route: AppRoutes.vendorDashboard, color: const Color(0xFF388E3C)),
        ServiceItem(icon: Icons.local_shipping,  label: 'My Pickups',      route: AppRoutes.vendorPickups,   color: const Color(0xFF1976D2)),
        ServiceItem(icon: Icons.move_to_inbox,   label: 'Drop Requests',   route: AppRoutes.vendorDropoff,   color: const Color(0xFFE64A19)),
        ServiceItem(icon: Icons.person,          label: 'My Profile',      route: AppRoutes.vendorProfile,   color: const Color(0xFF7B1FA2)),
      ];
    }

    return [
      ServiceItem(icon: Icons.recycling,            label: 'Home Pickup',    route: AppRoutes.pickup,        color: const Color(0xFF388E3C)),
      ServiceItem(icon: Icons.volunteer_activism,   label: 'Donate',         route: AppRoutes.donate,        color: const Color(0xFF1976D2)),
      ServiceItem(icon: Icons.location_on,          label: 'Drop Point',     route: AppRoutes.dropoff,       color: const Color(0xFFE64A19)),
      ServiceItem(icon: Icons.build_circle,         label: 'Refurbished',    route: AppRoutes.refurbished,   color: const Color(0xFF6D4C41)),
      ServiceItem(icon: Icons.card_giftcard,        label: 'Rewards',        route: AppRoutes.rewards,       color: const Color(0xFFF57C00)),
      ServiceItem(icon: Icons.picture_as_pdf,       label: 'Certificates',   route: AppRoutes.certificates,  color: const Color(0xFF00796B)),
      ServiceItem(icon: Icons.rate_review,          label: 'Reviews',        route: AppRoutes.reviews,       color: const Color(0xFF5C6BC0)),
      ServiceItem(icon: Icons.storefront,           label: 'Join as Vendor', route: AppRoutes.vendorRegister,color: const Color(0xFF0288D1)),
    ];
  }
}
