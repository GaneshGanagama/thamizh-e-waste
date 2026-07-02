// lib/screens/user/login_screen.dart
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../routes/app_routes.dart';
//import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:io' show Platform;
// ─────────────────────────────────────────────────────────────────────────────
// UNIFIED LOGIN SCREEN  —  User · Vendor · Admin

//
// All three roles use the same login page.
// Role detection happens automatically after login (reads 'role' from Firestore).
// Admin/Vendor are redirected to their dashboards; users go to home.
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  final String? nextRoute;
  const LoginScreen({super.key, this.nextRoute});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  late final TabController _tabCtrl;

  bool _loading = false;
  bool _obscurePassword = true;
  bool _acceptedPolicy = false;
  bool _useOtp = false;
  String? _verificationId;

  // Which role tab is selected (for display only — actual role from Firestore)
  int _roleTab = 0; // 0=User, 1=Vendor, 2=Admin

  static const _roles = ['User', 'Vendor', 'Admin'];
  static const _roleIcons = [
    Icons.person,
    Icons.store,
    Icons.admin_panel_settings
  ];
  static const _roleColors = [
    Color(0xFF388E3C),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A)
  ];
  static const _roleHints = [
    'Login with your registered email or phone',
    'Login with your vendor account email',
    'Login with your admin credentials',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _roleTab = _tabCtrl.index);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Color get _activeColor => _roleColors[_roleTab];

  // ── Auth actions ───────────────────────────────────────────────────────────
  Future<void> _loginEmail() async {
    if (!_policyCheck()) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _snack('Enter email and password');
      return;
    }
    setState(() => _loading = true);
    final err = await _authService.loginWithEmail(email, password);
    setState(() => _loading = false);
    if (err == null) {
      await _authService.navigateByRole(context, nextRoute: widget.nextRoute);
    } else {
      _snack(err);
    }
  }

  Future<void> _loginGoogle() async {
    if (!_policyCheck()) return;
    setState(() => _loading = true);
    final err = await _authService.loginWithGoogle();
    setState(() => _loading = false);
    if (err == null) {
      await _authService.navigateByRole(context, nextRoute: widget.nextRoute);
    } else {
      _snack(err);
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _snack('Enter phone number');
      return;
    }
    setState(() => _loading = true);
    final err = await _authService.sendOTP(phone, (verId) {
      setState(() => _verificationId = verId);
      _snack('OTP sent!');
    });
    setState(() => _loading = false);
    if (err != null) _snack(err);
  }

  Future<void> _verifyOtp() async {
    if (!_policyCheck()) return;
    if (_verificationId == null || _otpCtrl.text.isEmpty) {
      _snack('Enter OTP');
      return;
    }
    setState(() => _loading = true);
    final err =
        await _authService.verifyOTP(_verificationId!, _otpCtrl.text.trim());
    setState(() => _loading = false);
    if (err == null) {
      await _authService.navigateByRole(context, nextRoute: widget.nextRoute);
    } else {
      _snack(err);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack('Enter your email first');
      return;
    }
    final res = await _authService.forgotPassword(email);
    _snack(res ?? 'Password reset email sent!');
  }

  bool _policyCheck() {
    if (!_acceptedPolicy) {
      _snack('Please accept the Privacy Policy to continue');
      return false;
    }
    return true;
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Top green header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                decoration: BoxDecoration(
                  color: _activeColor,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                child: Column(children: [
                  // Logo / icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _roleIcons[_roleTab],
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Ecomeel',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_roleHints[_roleTab],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85), fontSize: 13)),
                ]),
              ),

              // ── Role tab bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      color: _activeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: List.generate(
                        3,
                        (i) => Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_roleIcons[i], size: 15),
                                  const SizedBox(width: 4),
                                  Text(_roles[i]),
                                ],
                              ),
                            )),
                  ),
                ),
              ),

              // ── Form ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(children: [
                  // OTP toggle (only for User tab)
                  if (_roleTab == 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(_useOtp ? 'Use Email' : 'Use OTP',
                            style:
                                TextStyle(fontSize: 13, color: _activeColor)),
                        Switch(
                          value: _useOtp,
                          activeColor: _activeColor,
                          onChanged: (v) => setState(() {
                            _useOtp = v;
                            _verificationId = null;
                          }),
                        ),
                      ],
                    ),
                  ],

                  // ── OTP fields ──────────────────────────────────────────
                  if (_useOtp && _roleTab == 0) ...[
                    _field(_phoneCtrl, 'Phone (+91...)', Icons.phone,
                        type: TextInputType.phone),
                    const SizedBox(height: 12),
                    _field(_otpCtrl, 'OTP', Icons.sms,
                        type: TextInputType.number),
                    const SizedBox(height: 20),
                    _primaryBtn(
                      label:
                          _verificationId == null ? 'Send OTP' : 'Verify OTP',
                      onTap: _verificationId == null ? _sendOtp : _verifyOtp,
                    ),
                  ]
                  // ── Email / password fields ────────────────────────────
                  else ...[
                    _field(_emailCtrl, 'Email', Icons.email,
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration(
                        label: 'Password',
                        icon: Icons.lock,
                        suffix: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: Text('Forgot Password?',
                            style:
                                TextStyle(color: _activeColor, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _primaryBtn(label: 'Login', onTap: _loginEmail),
                  ],

                  // ── Google sign-in (User + Vendor only) ─────────────────
                  if (_roleTab != 2) ...[
                    const SizedBox(height: 16),
                    Row(children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('or', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _loginGoogle,
                      icon: const Icon(Icons.g_mobiledata,
                          color: Colors.red, size: 24),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],

                  // ── Biometric (mobile only, User tab) ─────────────────────
                  if (_roleTab == 0 &&
                      !kIsWeb &&
                      (Platform.isAndroid || Platform.isIOS)) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              if (!_policyCheck()) return;
                              final supported =
                                  await _authService.canUseBiometrics();
                              if (!supported) {
                                _snack('Biometrics not available');
                                return;
                              }
                              final ok = await _authService.biometricLogin();
                              if (ok &&
                                  FirebaseAuth.instance.currentUser != null) {
                                await _authService.navigateByRole(context,
                                    nextRoute: widget.nextRoute);
                              } else {
                                _snack(
                                    'Login normally first to enable biometrics');
                              }
                            },
                      icon: const Icon(Icons.fingerprint, color: Colors.blue),
                      label: const Text('Login with Biometrics'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Privacy policy checkbox ────────────────────────────────
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: _activeColor,
                    value: _acceptedPolicy,
                    onChanged: (v) =>
                        setState(() => _acceptedPolicy = v ?? false),
                    title: GestureDetector(
                      onTap: () async {
                        final url =
                            Uri.parse('https://ecomeel.in/privacy-policy');
                        if (await canLaunchUrl(url)) await launchUrl(url);
                      },
                      child: const Text.rich(TextSpan(
                        text: 'I agree to the ',
                        style: TextStyle(fontSize: 13),
                        children: [
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline),
                          ),
                        ],
                      )),
                    ),
                  ),

                  // ── Sign up link (User only) ──────────────────────────────
                  if (_roleTab == 0) ...[
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.signup),
                      child: Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(color: _activeColor),
                      ),
                    ),
                  ],

                  // ── Admin hint ─────────────────────────────────────────────
                  if (_roleTab == 2)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            color: Colors.purple[700], size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin accounts are created by the system. '
                            'Contact your administrator if you need access.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.purple[800]),
                          ),
                        ),
                      ]),
                    ),

                  const SizedBox(height: 20),
                  Text(
                    'Powered by Thamizh E-Waste Pvt. Ltd.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _primaryBtn({required String label, required VoidCallback onTap}) =>
      ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _activeColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: _inputDecoration(label: label, icon: icon),
      );

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _activeColor, width: 1.5),
        ),
      );
}
