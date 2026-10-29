import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 ECOMEEL STARTUP: Flutter initialized');

  runApp(const _SplashWrapper());
}

class _SplashWrapper extends StatefulWidget {
  const _SplashWrapper({super.key});

  @override
  State<_SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<_SplashWrapper>
    with SingleTickerProviderStateMixin {
  bool _ready = false;
  bool _initializing = false;
  String? _error;

  late final AnimationController _animationController;
  final Stopwatch _startupTimer = Stopwatch();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _init();
  }

  Future<void> _init() async {
    // Prevent overlapping retries and duplicate Firebase initialization.
    if (_initializing || _ready || !mounted) return;

    _initializing = true;
    if (!_animationController.isAnimating) {
      _animationController.repeat();
    }

    _startupTimer
      ..reset()
      ..start();

    if (mounted) {
      setState(() {
        _error = null;
      });
    }

    debugPrint('🚀 ECOMEEL STARTUP: Firebase initialization started');

    try {
      // Reuse an existing Firebase app if FlutterFire already knows it.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        Firebase.app();
        debugPrint('ℹ️ ECOMEEL: Reusing existing Firebase app');
      }

      _startupTimer.stop();
      // Stop the splash animation after startup to avoid wasting CPU/battery.
      _animationController.stop();

      debugPrint(
        '✅ ECOMEEL STARTUP: Firebase initialized in '
        '${_startupTimer.elapsedMilliseconds} ms',
      );

      if (!mounted) return;

      setState(() {
        _ready = true;
        _error = null;
      });

      debugPrint('🏁 ECOMEEL STARTUP: App ready');
    } catch (e, st) {
      _startupTimer.stop();

      debugPrint('❌ ECOMEEL STARTUP: Firebase initialization failed');
      // Keep detailed diagnostics out of production logs/UI.
      if (kDebugMode) {
        debugPrint('FIREBASE INIT ERROR: $e');
        debugPrint('$st');
      }

      if (!mounted) return;

      setState(() {
        _error = kDebugMode
            ? e.toString()
            : 'App services could not be initialized. Please retry. '
                'If the problem continues, contact support.';
        _ready = false;
      });
    } finally {
      _initializing = false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _StartupErrorScreen(
        error: _error!,
        onRetry: _init,
      );
    }

    if (_ready) {
      return const EcomeelApp();
    }

    return _AnimatedSplash(
      animation: _animationController,
    );
  }
}

// -----------------------------------------------------------------------------
// Animated splash screen
// -----------------------------------------------------------------------------

class _AnimatedSplash extends StatelessWidget {
  final Animation<double> animation;

  const _AnimatedSplash({
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.green[700],
        body: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final rotation = animation.value * 2 * 3.14159265359;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: rotation * 0.15,
                      child: Transform.scale(
                        scale: 0.95 + (animation.value * 0.08),
                        child: Container(
                          width: 105,
                          height: 105,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              return Icon(
                                Icons.recycling,
                                color: Colors.green[700],
                                size: 65,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Ecomeel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'E-Waste Recycling',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Dot(active: animation.value < 0.33),
                        const SizedBox(width: 7),
                        _Dot(
                          active:
                              animation.value >= 0.33 && animation.value < 0.66,
                        ),
                        const SizedBox(width: 7),
                        _Dot(active: animation.value >= 0.66),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Preparing Ecomeel...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;

  const _Dot({
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 10 : 7,
      height: active ? 10 : 7,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withOpacity(0.35),
        shape: BoxShape.circle,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Startup error screen
// -----------------------------------------------------------------------------

class _StartupErrorScreen extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _StartupErrorScreen({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.green[700],
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.white,
                      size: 58,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Ecomeel could not start',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We could not initialize the app services. Please retry. '
                      'If the problem continues, check the app configuration or contact support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: kDebugMode
                          ? SelectableText(
                              error,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            )
                          : const Text(
                              'Please try again. If this continues, contact support.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Main application
// -----------------------------------------------------------------------------

class EcomeelApp extends StatefulWidget {
  const EcomeelApp({
    super.key,
  });

  static _EcomeelAppState of(BuildContext context) {
    final state = context.findAncestorStateOfType<_EcomeelAppState>();
    assert(state != null, 'EcomeelApp.of(context) called outside EcomeelApp');
    return state!;
  }

  @override
  State<EcomeelApp> createState() => _EcomeelAppState();
}

class _EcomeelAppState extends State<EcomeelApp> {
  Locale _locale = const Locale('en');

  void setLocale(Locale locale) {
    if (locale.languageCode != 'en' && locale.languageCode != 'ta') {
      return;
    }

    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecomeel',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ta'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: false,
      ),
      routes: appRoutes,
      initialRoute: AppRoutes.home,
    );
  }
}
