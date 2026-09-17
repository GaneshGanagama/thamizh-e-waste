// lib/main.dart

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
  const _SplashWrapper();

  @override
  State<_SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<_SplashWrapper>
    with SingleTickerProviderStateMixin {
  bool _ready = false;
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
    _startupTimer
      ..reset()
      ..start();

    debugPrint('🚀 ECOMEEL STARTUP: Firebase initialization started');

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _startupTimer.stop();

      debugPrint(
        '✅ ECOMEEL STARTUP: Firebase initialized in '
        '${_startupTimer.elapsedMilliseconds} ms',
      );

      if (!mounted) return;

      setState(() {
        _ready = true;
        _error = null;
      });

      debugPrint(
        '🏁 ECOMEEL STARTUP: App ready in '
        '${_startupTimer.elapsedMilliseconds} ms',
      );
    } catch (e, st) {
      _startupTimer.stop();

      debugPrint(
        '❌ ECOMEEL STARTUP: Firebase failed after '
        '${_startupTimer.elapsedMilliseconds} ms',
      );

      debugPrint('❌ FIREBASE INIT ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _ready = false;
      });
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
        onRetry: () {
          setState(() {
            _error = null;
          });

          _init();
        },
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

// ─────────────────────────────────────────────────────────────────────────────
// Animated Splash
// ─────────────────────────────────────────────────────────────────────────────

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
                          padding: const EdgeInsets.all(15),
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
                        _Dot(
                          active: animation.value < 0.33,
                        ),
                        const SizedBox(width: 7),
                        _Dot(
                          active:
                              animation.value >= 0.33 && animation.value < 0.66,
                        ),
                        const SizedBox(width: 7),
                        _Dot(
                          active: animation.value >= 0.66,
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Startup Error
// ─────────────────────────────────────────────────────────────────────────────

class _StartupErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

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
            child: Padding(
              padding: const EdgeInsets.all(28),
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
                    'We could not initialize the app services.',
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
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main App
// ─────────────────────────────────────────────────────────────────────────────

class EcomeelApp extends StatefulWidget {
  const EcomeelApp({
    super.key,
  });

  static _EcomeelAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_EcomeelAppState>()!;

  @override
  State<EcomeelApp> createState() => _EcomeelAppState();
}

class _EcomeelAppState extends State<EcomeelApp> {
  Locale _locale = const Locale('en');

  void setLocale(Locale locale) {
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
