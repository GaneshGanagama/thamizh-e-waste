// Fallback for Web (Crashlytics not supported on Web)

class FirebaseCrashlytics {
  static final FirebaseCrashlytics instance = FirebaseCrashlytics();

  void recordFlutterError(dynamic error) {
    // Ignore crashlytics on web
    print("WEB ERROR (Flutter): $error");
  }

  void recordError(dynamic exception, StackTrace? stack, {bool fatal = false}) {
    print("WEB ERROR (Exception): $exception");
  }

  void crash() {
    print("WEB CRASH TRIGGERED");
  }
}
