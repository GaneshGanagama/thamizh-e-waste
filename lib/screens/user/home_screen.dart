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

// ─────────────────────────────────────────────────────────────────────────────
// Bilingual strings — edit here to change any text in EN or Tamil
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final String lang;
  const _S(this.lang);
  bool get isTa => lang == 'ta';

  String get appName => 'Ecomeel';
  String get login => isTa ? 'உள்நுழை' : 'Login';
  String get trackPickups => isTa ? 'என் பிக்கப்கள்' : 'Track My Pickups';
  String get ourServices => isTa ? 'எங்கள் சேவைகள்' : 'Our Services';
  String get announcements => isTa ? 'அறிவிப்புகள்' : 'Announcements';
  String get privacyPolicy => isTa ? 'தனியுரிமை கொள்கை' : 'Privacy Policy';
  String get iAgree => isTa ? 'ஒப்புக்கொள்கிறேன்' : 'I Agree';
  String get viewPolicy => isTa ? 'கொள்கையை காண்க' : 'View Policy';
  String get privacyBody => isTa
      ? 'Ecomeel பாதுகாப்பான உள்நுழைவு மற்றும் சேமிப்பிற்கு Firebase பயன்படுத்துகிறது. எங்கள் மின்கழிவு மறுசுழற்சி சேவைகளை வழங்க குறைந்தபட்ச தரவை மட்டுமே சேகரிக்கிறோம்.'
      : 'Ecomeel uses Firebase for secure login and storage. We collect minimal data to provide our e-waste recycling services.';
  String get customerReviews =>
      isTa ? 'வாடிக்கையாளர் கருத்துகள்' : 'Customer Reviews';
  String get reviewsSubtitle => isTa
      ? 'உங்கள் மறுசுழற்சி அனுபவத்தை பகிர்ந்து கொள்ளுங்கள்'
      : 'Share your recycling experience and help others';
  String get viewAllReviews => isTa ? 'அனைத்தையும் காண்க' : 'View All Reviews';
  String get writeReview => isTa ? 'கருத்து எழுதுங்கள்' : 'Write a Review';
  String get noReviewsYet => isTa
      ? 'இன்னும் கருத்துகள் இல்லை. முதலில் எழுதுங்கள்!'
      : 'No reviews yet. Be the first!';
  String get contactUs => isTa ? 'தொடர்பு கொள்ளுங்கள்' : 'Contact Us';
  String get serviceAreaValue =>
      isTa ? 'தமிழ்நாடு, இந்தியா' : 'Tamil Nadu, India';
  String get followUs => isTa ? 'எங்களை பின்தொடருங்கள்' : 'Follow Us';
  String get termsConditions => isTa ? 'விதிமுறைகள்' : 'Terms & Conditions';
  String get aboutUs => isTa ? 'எங்களை பற்றி' : 'About Us';
  String get faq => 'FAQ';
  String get copyright =>
      '© 2026 Thamizh E Waste Private Limited. ${isTa ? "அனைத்து உரிமைகளும் பாதுகாக்கப்பட்டவை." : "All Rights Reserved."}';
  String get madeWith => isTa ? 'அன்புடன் உருவாக்கப்பட்டது' : 'Made with ♥ by';
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final bool isVendor;
  final bool showLoginButton;

  const HomeScreen({
    super.key,
    this.isVendor = false,
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

  static const double _kDesktop = 900;
  static const double _kMaxWidth = 1100;

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
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('app_language');
    if (saved != null && saved != _language && mounted) {
      setState(() => _language = saved);
      EcomeelApp.of(context).setLocale(Locale(saved));
    }
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
    final s = _S(_language);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.privacy_tip_outlined, color: Colors.green[700], size: 22),
          const SizedBox(width: 8),
          Text(s.privacyPolicy),
        ]),
        content: Text(s.privacyBody),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.parse('https://ecomeel.in/privacy-policy');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Text(s.viewPolicy),
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
            child: Text(s.iAgree),
          ),
        ],
      ),
    );
  }

  void _toggleLanguage() async {
    final newLang = _language == 'en' ? 'ta' : 'en';
    setState(() => _language = newLang);
    EcomeelApp.of(context).setLocale(Locale(newLang));
    final p = await SharedPreferences.getInstance();
    await p.setString('app_language', newLang);
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _S(_language);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > _kDesktop;
    final isLoggedIn = _currentUser != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        elevation: 0,
        title: Row(children: [
          _AppLogo(),
          const SizedBox(width: 8),
          Text(s.appName,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        ]),
        actions: [
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
              tooltip: s.trackPickups,
              icon: const Icon(Icons.local_shipping_outlined,
                  color: Colors.white),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.track),
            ),
          if (!isLoggedIn)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              child: Text(s.login,
                  style: const TextStyle(
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
          child: isDesktop
              ? _DesktopLayout(
                  language: _language,
                  isVendor: widget.isVendor,
                  maxWidth: _kMaxWidth,
                  width: width,
                  openRoute: _openRoute,
                  launchUrl: _launchUrl,
                  showPrivacyDialog: _showPrivacyDialog,
                  s: s,
                )
              : _MobileLayout(
                  language: _language,
                  isVendor: widget.isVendor,
                  width: width,
                  openRoute: _openRoute,
                  launchUrl: _launchUrl,
                  showPrivacyDialog: _showPrivacyDialog,
                  s: s,
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE LAYOUT — single column
// ─────────────────────────────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final String language;
  final bool isVendor;
  final double width;
  final void Function(String) openRoute;
  final Future<void> Function(String) launchUrl;
  final VoidCallback showPrivacyDialog;
  final _S s;

  const _MobileLayout({
    required this.language,
    required this.isVendor,
    required this.width,
    required this.openRoute,
    required this.launchUrl,
    required this.showPrivacyDialog,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Banners
        const _BannerSection(),
        const SizedBox(height: 12),

        // 2. Our Services
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(s.ourServices,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800])),
        ),
        ServiceGrid(
          services: FirestoreService.instance.servicesList(isVendor, language),
          screenWidth: width,
          onTap: openRoute,
        ),

        // 3. Impact
        const SizedBox(height: 4),
        const ImpactSection(),

        // 4. Mission
        const MissionSection(),

        // 5. Announcements
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(s.announcements,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800])),
        ),
        const Announcements(),

        // 6. Reviews
        const SizedBox(height: 8),
        _ReviewsSection(language: language, onTap: openRoute),

        // 7. Contact + Social
        const SizedBox(height: 8),
        _ContactSection(language: language, onLaunch: launchUrl),

        // 8. Footer
        const SizedBox(height: 8),
        _FooterSection(
            language: language,
            onPrivacy: showPrivacyDialog,
            onLaunch: launchUrl),

        const SizedBox(height: 80),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP LAYOUT — 2 column with centered max width
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final String language;
  final bool isVendor;
  final double maxWidth;
  final double width;
  final void Function(String) openRoute;
  final Future<void> Function(String) launchUrl;
  final VoidCallback showPrivacyDialog;
  final _S s;

  const _DesktopLayout({
    required this.language,
    required this.isVendor,
    required this.maxWidth,
    required this.width,
    required this.openRoute,
    required this.launchUrl,
    required this.showPrivacyDialog,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Banners — full width
        const _BannerSection(),
        const SizedBox(height: 24),

        // 2+3. Services (left) + Impact (right) — 2 columns
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: Services
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.ourServices,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800])),
                        const SizedBox(height: 12),
                        ServiceGrid(
                          services: FirestoreService.instance
                              .servicesList(isVendor, language),
                          screenWidth: width,
                          onTap: openRoute,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // RIGHT: Impact
                  const Expanded(
                    flex: 2,
                    child: ImpactSection(),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 4. Mission — full width centered
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: MissionSection(),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 5. Announcements — full width centered
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.announcements,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  const Announcements(),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 6. Reviews — full width centered
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ReviewsSection(
                  language: language, onTap: openRoute, isDesktop: true),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 7. Contact + Social — 2 columns on desktop
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ContactSection(
                  language: language, onLaunch: launchUrl, isDesktop: true),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 8. Footer — full width
        _FooterSection(
            language: language,
            onPrivacy: showPrivacyDialog,
            onLaunch: launchUrl,
            isDesktop: true),

        const SizedBox(height: 40),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reviews Section
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewsSection extends StatelessWidget {
  final String language;
  final void Function(String) onTap;
  final bool isDesktop;

  const _ReviewsSection({
    required this.language,
    required this.onTap,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = _S(language);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.star_rounded, color: Colors.orange[700], size: 20),
            const SizedBox(width: 6),
            Text(s.customerReviews,
                style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800])),
          ]),
          const SizedBox(height: 4),
          Text(s.reviewsSubtitle,
              style: TextStyle(fontSize: 12, color: Colors.orange[600])),
          const SizedBox(height: 12),

          // Live reviews from Firestore
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reviews')
                .where('approved', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .limit(isDesktop ? 3 : 3)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(s.noReviewsYet,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic)),
                );
              }

              final docs = snap.data!.docs;

              // Desktop: show reviews in a row
              if (isDesktop) {
                return Row(
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final rating = (d['rating'] as num? ?? 5).toInt();
                    final name = d['userName'] ?? 'User';
                    final text = d['review'] ?? '';
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              ...List.generate(
                                  5,
                                  (i) => Icon(
                                        i < rating
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        color: Colors.orange,
                                        size: 14,
                                      )),
                              const SizedBox(width: 6),
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ]),
                            if (text.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(text,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              }

              // Mobile: stacked
              return Column(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final rating = (d['rating'] as num? ?? 5).toInt();
                  final name = d['userName'] ?? 'User';
                  final text = d['review'] ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          ...List.generate(
                              5,
                              (i) => Icon(
                                    i < rating
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.orange,
                                    size: 14,
                                  )),
                          const SizedBox(width: 6),
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                        ]),
                        if (text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(text,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87)),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onTap(AppRoutes.reviews),
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: Text(s.viewAllReviews,
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange[700],
                  side: BorderSide(color: Colors.orange.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onTap(AppRoutes.reviews),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label:
                    Text(s.writeReview, style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact + Social Section
// ─────────────────────────────────────────────────────────────────────────────
class _ContactSection extends StatelessWidget {
  final String language;
  final Future<void> Function(String) onLaunch;
  final bool isDesktop;

  const _ContactSection({
    required this.language,
    required this.onLaunch,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = _S(language);
    final contactInfo = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.contact_phone, color: Colors.green[700], size: 20),
            const SizedBox(width: 6),
            Text(s.contactUs,
                style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800])),
          ]),
          const SizedBox(height: 12),
          _ContactRow(
              icon: Icons.business,
              label: 'Thamizh E Waste Private Limited',
              color: Colors.green[700]!),
          _ContactRow(
              icon: Icons.person_outline,
              label: 'D. Thamizhmani, B.Tech.',
              color: Colors.green[700]!),
          GestureDetector(
            onTap: () => onLaunch('tel:+919787555916'),
            child: _ContactRow(
                icon: Icons.phone,
                label: '+91 97875 55916',
                color: Colors.green[700]!,
                isLink: true),
          ),
          GestureDetector(
            onTap: () => onLaunch('mailto:thamizhewaste@gmail.com'),
            child: _ContactRow(
                icon: Icons.email_outlined,
                label: 'thamizhewaste@gmail.com',
                color: Colors.green[700]!,
                isLink: true),
          ),
          GestureDetector(
            onTap: () => onLaunch('https://ecomeel.in'),
            child: _ContactRow(
                icon: Icons.language,
                label: 'ecomeel.in',
                color: Colors.green[700]!,
                isLink: true),
          ),
          _ContactRow(
              icon: Icons.location_on_outlined,
              label: s.serviceAreaValue,
              color: Colors.green[700]!),
        ],
      ),
    );

    final socialInfo = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.share, color: Colors.blue[700], size: 18),
            const SizedBox(width: 6),
            Text(s.followUs,
                style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800])),
          ]),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              _SocialButton(
                icon: Icons.camera_alt_outlined,
                label: 'Instagram',
                color: const Color(0xFFE1306C),
                onTap: () => onLaunch(
                    'https://www.instagram.com/thamizhmani_datshnamoorthy/'),
              ),
              _SocialButton(
                icon: Icons.work_outline,
                label: 'LinkedIn',
                color: const Color(0xFF0077B5),
                onTap: () => onLaunch(
                    'https://www.linkedin.com/in/thamizhmani-datshnamoorthy/'),
              ),
              _SocialButton(
                icon: Icons.play_circle_outline,
                label: 'YouTube',
                color: const Color(0xFFFF0000),
                onTap: () => onLaunch(
                    'https://www.youtube.com/results?search_query=Thamizh+E+Waste'),
              ),
              _SocialButton(
                icon: Icons.language,
                label: 'Website',
                color: Colors.green[700]!,
                onTap: () => onLaunch('https://ecomeel.in'),
              ),
            ],
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: contactInfo),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: socialInfo),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        contactInfo,
        const SizedBox(height: 12),
        socialInfo,
      ]),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLink;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.color,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                color: isLink ? Colors.blue[700] : Colors.black87,
                decoration:
                    isLink ? TextDecoration.underline : TextDecoration.none,
              )),
        ),
      ]),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────────────────────
class _FooterSection extends StatelessWidget {
  final String language;
  final VoidCallback onPrivacy;
  final Future<void> Function(String) onLaunch;
  final bool isDesktop;

  const _FooterSection({
    required this.language,
    required this.onPrivacy,
    required this.onLaunch,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = _S(language);
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.fromLTRB(isDesktop ? 40 : 16, 16, isDesktop ? 40 : 16, 8),
      color: Colors.grey[100],
      child: Column(children: [
        const Divider(),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton(
              onPressed: onPrivacy,
              child: Text(s.privacyPolicy,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () => onLaunch('https://ecomeel.in/terms'),
              child: Text(s.termsConditions,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () => onLaunch('https://ecomeel.in/about'),
              child: Text(s.aboutUs,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () => onLaunch('https://ecomeel.in/faq'),
              child: Text(s.faq,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(s.copyright,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 4),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            children: [
              TextSpan(text: '${s.madeWith} '),
              TextSpan(
                text: 'Ganesh Gangama',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner Section
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
          color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Logo
// ─────────────────────────────────────────────────────────────────────────────
class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
              color: Colors.white24, borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.eco, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
