// lib/screens/user/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../../services/firestore_service.dart';
import '../../widgets/banner_slider.dart';
import '../../widgets/service_grid.dart';
import '../../widgets/impact_section.dart';
import '../../widgets/mission_section.dart';
import '../../widgets/announcements.dart';
import '../../widgets/chatbot_fab.dart';
import '../../utils/auth_guard.dart';
import '../../routes/app_routes.dart';

class HomeScreen extends StatefulWidget {
  final bool isVendor;
  final Function(String) onLanguageChange;
  final bool showLoginButton;

  const HomeScreen({
    super.key,
    this.isVendor = false,
    required this.onLanguageChange,
    this.showLoginButton = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _language = 'en';
  bool _showTop = false;
  final ScrollController _sc = ScrollController();
  StreamSubscription<User?>? _authSub;
  User? _currentUser;

  @override
  void initState() {
    super.initState();

    _sc.addListener(() {
      final show = _sc.offset > 300;
      if (show != _showTop) setState(() => _showTop = show);
    });

    _currentUser = FirebaseAuth.instance.currentUser;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) setState(() => _currentUser = u);
    });

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkPrivacyAccepted());
  }

  @override
  void dispose() {
    _sc.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkPrivacyAccepted() async {
    if (!mounted) return;
    final p = await SharedPreferences.getInstance();
    final accepted = p.getBool('accepted_privacy_policy') ?? false;
    if (!accepted && mounted) _showPrivacyDialog();
  }

  void _showPrivacyDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.privacy_tip_outlined, color: Colors.green[700], size: 22),
          const SizedBox(width: 8),
          const Text('Privacy Policy'),
        ]),
        content: const Text(
          'Ecomeel uses Firebase for secure login and storage. '
          'We collect minimal data to provide our e-waste recycling services.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.parse('https://ecomeel.in/privacy-policy');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('View Policy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final p = await SharedPreferences.getInstance();
              await p.setBool('accepted_privacy_policy', true);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('I Agree'),
          ),
        ],
      ),
    );
  }

  // ── Language toggle EN ↔ Tamil ─────────────────────────────────────────────
  void _toggleLanguage() {
    final newLang = _language == 'en' ? 'ta' : 'en';
    setState(() => _language = newLang);
    widget.onLanguageChange(newLang);
    // Now works because EcomeelApp is a StatefulWidget with setLocale()
    EcomeelApp.of(context).setLocale(Locale(newLang));
  }

  void _openRoute(String route) {
    const needLogin = {
      AppRoutes.pickup,
      AppRoutes.donate,
      AppRoutes.dropoff,
      AppRoutes.vendorRegister,
      AppRoutes.rewards,
      AppRoutes.certificates,
      AppRoutes.profile,
    };
    if (needLogin.contains(route)) {
      requireLogin(context,
          onSuccess: () => Navigator.pushNamed(context, route));
      return;
    }
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isLoggedIn = _currentUser != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        elevation: 0,
        title: Row(children: [
          _AppLogo(),
          const SizedBox(width: 8),
          const Text('Ecomeel',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        ]),
        actions: [
          // ── Language toggle button ──────────────────────────────────────
          GestureDetector(
            onTap: _toggleLanguage,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _language == 'en' ? 'தமிழ்' : 'EN',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
          ),
          if (isLoggedIn)
            IconButton(
              tooltip: 'Track My Pickups',
              icon: const Icon(Icons.local_shipping_outlined,
                  color: Colors.white),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.track),
            ),
          // Show Login button when not logged in (always show it on home)
          if (!isLoggedIn)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              child: const Text('Login',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          if (isLoggedIn)
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Text(
                    (_currentUser?.displayName?.isNotEmpty == true
                            ? _currentUser!.displayName![0]
                            : _currentUser?.email?[0] ?? 'U')
                        .toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showTop) ...[
            FloatingActionButton(
              heroTag: 'scrollTop',
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: Colors.green[700],
              elevation: 3,
              onPressed: () => _sc.animateTo(0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut),
              child: const Icon(Icons.arrow_upward, size: 20),
            ),
            const SizedBox(height: 8),
          ],
          const ChatBotFAB(),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _sc,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banners ──────────────────────────────────────────────────
              const _BannerSection(),
              const SizedBox(height: 12),

              // ── Services grid ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _language == 'ta' ? 'எங்கள் சேவைகள்' : 'Our Services',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800]),
                ),
              ),
              ServiceGrid(
                services: FirestoreService.instance
                    .servicesList(widget.isVendor, _language),
                screenWidth: width,
                onTap: _openRoute,
              ),

              const SizedBox(height: 4),
              const ImpactSection(),
              const MissionSection(),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _language == 'ta' ? 'அறிவிப்புகள்' : 'Announcements',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800]),
                ),
              ),
              const Announcements(),

              // ── Footer ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(children: [
                  const Divider(),
                  TextButton.icon(
                    onPressed: _showPrivacyDialog,
                    icon: Icon(Icons.privacy_tip_outlined,
                        size: 14, color: Colors.grey[600]),
                    label: Text('Privacy Policy',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ),
                  Text('© 2025 Ecomeel. All rights reserved.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ]),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BannerSection — Firestore stream with asset fallback
// ─────────────────────────────────────────────────────────────────────────────
class _BannerSection extends StatelessWidget {
  const _BannerSection();

  static const _fallback = [
    'assets/images/THAMIZH-01.png',
    'assets/images/THAMIZH-02.png',
    'assets/images/THAMIZH-03.png',
    'assets/images/THAMIZH-04.png',
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('banners')
          .orderBy('order')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _placeholder();
        }
        if (snap.hasError || !snap.hasData || snap.data!.docs.isEmpty) {
          return BannerSlider(images: _fallback);
        }

        final images = <String>[];
        final links = <String>[];

        for (final doc in snap.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final url = (data['imageUrl'] ?? '').toString().trim();
          if (url.isNotEmpty) {
            images.add(url);
            links.add((data['link'] ?? '').toString());
          }
        }

        if (images.isEmpty) return BannerSlider(images: _fallback);
        return BannerSlider(images: images, links: links);
      },
    );
  }

  Widget _placeholder() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AppLogo — tries logo.png first, then logo.jpg, then icon fallback
// Put your logo file at assets/images/logo.png (or logo.jpg)
// ─────────────────────────────────────────────────────────────────────────────
class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Try PNG first (most common), then JPG — both gracefully fall back to icon
    return Image.asset(
      'assets/images/logo.png',
      height: 32,
      width: 32,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/logo.jpg',
        height: 32,
        width: 32,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
