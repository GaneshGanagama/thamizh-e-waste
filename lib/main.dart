// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const EcomeelApp());
}

// ── StatefulWidget so locale can be changed at runtime ──────────────────────
class EcomeelApp extends StatefulWidget {
  const EcomeelApp({super.key});

  /// Call from anywhere in the tree to switch locale.
  static _EcomeelAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_EcomeelAppState>()!;

  @override
  State<EcomeelApp> createState() => _EcomeelAppState();
}

class _EcomeelAppState extends State<EcomeelApp> {
  Locale _locale = const Locale('en');

  void setLocale(Locale locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecomeel',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('ta')],
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
