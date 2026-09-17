import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../routes/app_routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UNIFIED LOGIN SCREEN — User · Vendor · Admin
//
// USER:
//   Normal Ecomeel user → Home
//
// VENDOR:
//   Must have an approved document in vendors/{uid}
//   → Vendor Dashboard
//
// ADMIN:
//   Must have admin role
//   → Admin Dashboard
//
// One Firebase account can therefore have both:
//   USER access + VENDOR access.
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  final String? nextRoute;

  const LoginScreen({
    super.key,
    this.nextRoute,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();

  late final TabController _tabCtrl;

  bool _loading = false;
  bool _obscurePassword = true;
  bool _acceptedPolicy = false;
  bool _useOtp = false;

  String? _verificationId;

  // 0 = User
  // 1 = Vendor
  // 2 = Admin
  int _roleTab = 0;

  static const List<String> _roles = [
    'User',
    'Vendor',
    'Admin',
  ];

  static const List<IconData> _roleIcons = [
    Icons.person,
    Icons.store,
    Icons.admin_panel_settings,
  ];

  static const List<Color> _roleColors = [
    Color(0xFF388E3C),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
  ];

  static const List<String> _roleHints = [
    'Login with your registered email or phone',
    'Login with your approved vendor account',
    'Login with your administrator credentials',
  ];

  @override
  void initState() {
    super.initState();

    _tabCtrl = TabController(
      length: 3,
      vsync: this,
    );

    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging && mounted) {
        setState(() {
          _roleTab = _tabCtrl.index;

          // Reset OTP when switching tabs.
          if (_roleTab != 0) {
            _useOtp = false;
            _verificationId = null;
          }
        });
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

  // ===========================================================================
  // EMAIL / PASSWORD LOGIN
  // ===========================================================================

  Future<void> _loginEmail() async {
    if (!_policyCheck()) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty) {
      _snack('Enter your email');
      return;
    }

    if (password.isEmpty) {
      _snack('Enter your password');
      return;
    }

    if (_loading) return;

    setState(() {
      _loading = true;
    });

    String? error;

    try {
      // -----------------------------------------------------------------------
      // USER LOGIN
      // -----------------------------------------------------------------------
      if (_roleTab == 0) {
        error = await _authService.loginAsUser(
          email,
          password,
        );
      }

      // -----------------------------------------------------------------------
      // VENDOR LOGIN
      // -----------------------------------------------------------------------
      else if (_roleTab == 1) {
        error = await _authService.loginAsVendor(
          email,
          password,
        );
      }

      // -----------------------------------------------------------------------
      // ADMIN LOGIN
      // -----------------------------------------------------------------------
      else if (_roleTab == 2) {
        error = await _authService.loginAsAdmin(
          email,
          password,
        );
      }

      if (!mounted) return;

      // -----------------------------------------------------------------------
      // LOGIN FAILED
      // -----------------------------------------------------------------------
      if (error != null) {
        _snack(error);
        return;
      }

      // -----------------------------------------------------------------------
      // LOGIN SUCCESS
      // -----------------------------------------------------------------------

      // USER → HOME
      if (_roleTab == 0) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          widget.nextRoute ?? AppRoutes.home,
          (_) => false,
        );
      }

      // APPROVED VENDOR → VENDOR DASHBOARD
      else if (_roleTab == 1) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.vendorDashboard,
          (_) => false,
        );
      }

      // ADMIN → ADMIN DASHBOARD
      else if (_roleTab == 2) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.admin,
          (_) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');

      if (mounted) {
        _snack(
          'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ===========================================================================
  // GOOGLE LOGIN
  // ===========================================================================

  Future<void> _loginGoogle() async {
    if (!_policyCheck()) return;

    // Google login is currently available for User.
    //
    // Vendor Google login requires additional handling because the vendor
    // account must first be verified against vendors/{uid}.
    if (_roleTab == 1) {
      _snack(
        'For Vendor login, please use your registered vendor email and password.',
      );
      return;
    }

    if (_roleTab == 2) {
      _snack(
        'Admin accounts must use administrator email and password.',
      );
      return;
    }

    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final error = await _authService.loginWithGoogle();

      if (!mounted) return;

      if (error != null) {
        _snack(error);
        return;
      }

      // Google login here is USER login.
      Navigator.pushNamedAndRemoveUntil(
        context,
        widget.nextRoute ?? AppRoutes.home,
        (_) => false,
      );
    } catch (e) {
      debugPrint('❌ Google login error: $e');

      if (mounted) {
        _snack(
          'Google login failed. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ===========================================================================
  // SEND OTP
  // ===========================================================================

  Future<void> _sendOtp() async {
    if (_roleTab != 0) {
      _snack('OTP login is available for User accounts only');
      return;
    }

    final phone = _phoneCtrl.text.trim();

    if (phone.isEmpty) {
      _snack('Enter phone number');
      return;
    }

    if (_loading) return;

    setState(() {
      _loading = true;
      _verificationId = null;
    });

    try {
      final error = await _authService.sendOTP(
        phone,
        (verificationId) {
          if (!mounted) return;

          setState(() {
            _verificationId = verificationId;
          });

          _snack('OTP sent successfully');
        },
      );

      if (!mounted) return;

      if (error != null) {
        _snack(error);
      }
    } catch (e) {
      debugPrint('❌ Send OTP error: $e');

      if (mounted) {
        _snack(
          'Could not send OTP. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ===========================================================================
  // VERIFY OTP
  // ===========================================================================

  Future<void> _verifyOtp() async {
    if (!_policyCheck()) return;

    if (_roleTab != 0) {
      _snack('OTP login is available for User accounts only');
      return;
    }

    if (_verificationId == null) {
      _snack('Please request an OTP first');
      return;
    }

    final otp = _otpCtrl.text.trim();

    if (otp.isEmpty) {
      _snack('Enter OTP');
      return;
    }

    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final error = await _authService.verifyOTP(
        _verificationId!,
        otp,
      );

      if (!mounted) return;

      if (error != null) {
        _snack(error);
        return;
      }

      // OTP is User login.
      Navigator.pushNamedAndRemoveUntil(
        context,
        widget.nextRoute ?? AppRoutes.home,
        (_) => false,
      );
    } catch (e) {
      debugPrint('❌ OTP verification error: $e');

      if (mounted) {
        _snack(
          'OTP verification failed. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ===========================================================================
  // FORGOT PASSWORD
  // ===========================================================================

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      _snack('Enter your email first');
      return;
    }

    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final result = await _authService.forgotPassword(email);

      if (!mounted) return;

      _snack(
        result ?? 'Password reset email sent!',
      );
    } catch (e) {
      debugPrint('❌ Forgot password error: $e');

      if (mounted) {
        _snack(
          'Could not send password reset email.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ===========================================================================
  // PRIVACY POLICY
  // ===========================================================================

  bool _policyCheck() {
    if (!_acceptedPolicy) {
      _snack(
        'Please accept the Privacy Policy to continue',
      );
      return false;
    }

    return true;
  }

  Future<void> _openPrivacyPolicy() async {
    final url = Uri.parse(
      'https://ecomeel.in/privacy-policy',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _snack('Could not open Privacy Policy');
      }
    } catch (e) {
      debugPrint('❌ Privacy Policy error: $e');
      _snack('Could not open Privacy Policy');
    }
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // =================================================================
              // HEADER
              // =================================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  24,
                  32,
                  24,
                  28,
                ),
                decoration: BoxDecoration(
                  color: _activeColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
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
                    const Text(
                      'Ecomeel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roleHints[_roleTab],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // =================================================================
              // ROLE TAB BAR
              // =================================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  0,
                ),
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
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: List.generate(
                      3,
                      (index) {
                        return Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _roleIcons[index],
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _roles[index],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // =================================================================
              // FORM
              // =================================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  24,
                ),
                child: Column(
                  children: [
                    // =============================================================
                    // USER OTP SWITCH
                    // =============================================================

                    if (_roleTab == 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _useOtp ? 'Use Email' : 'Use OTP',
                            style: TextStyle(
                              fontSize: 13,
                              color: _activeColor,
                            ),
                          ),
                          Switch(
                            value: _useOtp,
                            activeColor: _activeColor,
                            onChanged: _loading
                                ? null
                                : (value) {
                                    setState(() {
                                      _useOtp = value;
                                      _verificationId = null;
                                      _otpCtrl.clear();
                                    });
                                  },
                          ),
                        ],
                      ),
                    ],

                    // =============================================================
                    // OTP LOGIN
                    // =============================================================

                    if (_useOtp && _roleTab == 0) ...[
                      _field(
                        _phoneCtrl,
                        'Phone (+91...)',
                        Icons.phone,
                        type: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _otpCtrl,
                        'OTP',
                        Icons.sms,
                        type: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      _primaryBtn(
                        label:
                            _verificationId == null ? 'Send OTP' : 'Verify OTP',
                        onTap: _verificationId == null ? _sendOtp : _verifyOtp,
                      ),
                    ]

                    // =============================================================
                    // EMAIL LOGIN
                    // =============================================================

                    else ...[
                      _field(
                        _emailCtrl,
                        _roleTab == 1
                            ? 'Vendor Email'
                            : _roleTab == 2
                                ? 'Admin Email'
                                : 'Email',
                        Icons.email,
                        type: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        enabled: !_loading,
                        decoration: _inputDecoration(
                          label: 'Password',
                          icon: Icons.lock,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: _activeColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _primaryBtn(
                        label: _roleTab == 0
                            ? 'Login as User'
                            : _roleTab == 1
                                ? 'Login as Vendor'
                                : 'Login as Admin',
                        onTap: _loginEmail,
                      ),
                    ],

                    // =============================================================
                    // GOOGLE
                    // =============================================================

                    if (_roleTab == 0) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          Expanded(
                            child: Divider(),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'or',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _loginGoogle,
                        icon: const Icon(
                          Icons.g_mobiledata,
                          color: Colors.red,
                          size: 24,
                        ),
                        label: const Text(
                          'Continue with Google',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: const BorderSide(
                            color: Colors.grey,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],

                    // =============================================================
                    // BIOMETRIC — USER ONLY
                    // =============================================================

                    if (_roleTab == 0 &&
                        !kIsWeb &&
                        (defaultTargetPlatform == TargetPlatform.android ||
                            defaultTargetPlatform == TargetPlatform.iOS)) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () async {
                                if (!_policyCheck()) return;

                                final supported =
                                    await _authService.canUseBiometrics();

                                if (!supported) {
                                  _snack(
                                    'Biometrics not available',
                                  );
                                  return;
                                }

                                final ok = await _authService.biometricLogin();

                                if (!mounted) return;

                                if (ok &&
                                    FirebaseAuth.instance.currentUser != null) {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    widget.nextRoute ?? AppRoutes.home,
                                    (_) => false,
                                  );
                                } else {
                                  _snack(
                                    'Login normally first to enable biometrics',
                                  );
                                }
                              },
                        icon: const Icon(
                          Icons.fingerprint,
                          color: Colors.blue,
                        ),
                        label: const Text(
                          'Login with Biometrics',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: const BorderSide(
                            color: Colors.grey,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // =============================================================
                    // PRIVACY POLICY
                    // =============================================================

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: _activeColor,
                      value: _acceptedPolicy,
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() {
                                _acceptedPolicy = value ?? false;
                              });
                            },
                      title: GestureDetector(
                        onTap: _openPrivacyPolicy,
                        child: const Text.rich(
                          TextSpan(
                            text: 'I agree to the ',
                            style: TextStyle(
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // =============================================================
                    // SIGN UP — USER ONLY
                    // =============================================================

                    if (_roleTab == 0) ...[
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.signup,
                                );
                              },
                        child: Text(
                          "Don't have an account? Sign Up",
                          style: TextStyle(
                            color: _activeColor,
                          ),
                        ),
                      ),
                    ],

                    // =============================================================
                    // VENDOR INFORMATION
                    // =============================================================

                    if (_roleTab == 1)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blue.shade200,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.store,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Vendor access is available only after your vendor application has been approved by Ecomeel.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // =============================================================
                    // ADMIN INFORMATION
                    // =============================================================

                    if (_roleTab == 2)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.purple.shade200,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.purple[700],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Admin accounts are created by the system. Contact your administrator if you need access.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    Text(
                      'Powered by Thamizh E-Waste Pvt. Ltd.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PRIMARY BUTTON
  // ===========================================================================

  Widget _primaryBtn({
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: _loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _activeColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(
          double.infinity,
          50,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  // ===========================================================================
  // TEXT FIELD
  // ===========================================================================

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      enabled: !_loading,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
      ),
    );
  }

  // ===========================================================================
  // INPUT DECORATION
  // ===========================================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: _activeColor,
          width: 1.5,
        ),
      ),
    );
  }
}
