// lib/config/supabase_config.dart
class SupabaseConfig {
  // Provide your supabase base via --dart-define when running.
  // Example:
  // flutter run --dart-define=SUPABASE_URL=https://bvgefmcgbljezbhvpikh.supabase.co
  static const _base = String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  /// Returns the base URL (without trailing slash).
  static String get base {
    if (_base.trim().isEmpty) {
      // fallback to hardcoded (only for dev). Replace or use dart-define in production.
      return 'https://bvgefmcgbljezbhvpikh.supabase.co';
    }
    // remove trailing slash if any
    return _base.endsWith('/') ? _base.substring(0, _base.length - 1) : _base;
  }

  /// Normalize a stored Supabase path or a full url into a usable HTTP URL:
  /// - if `url` already starts with http -> return as-is
  /// - if `url` contains storage/v1/object/public -> attach base properly
  /// - otherwise treat as "bucket/path" and return storage/v1/object/public/<url>
  static String normalize(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http')) return trimmed;

    final b = base;

    if (trimmed.contains('storage/v1/object/public')) {
      // path could be '/storage/v1/object/public/...'
      if (trimmed.startsWith('/')) return '$b$trimmed';
      return '$b/$trimmed';
    }

    // treat as bucket path
    // e.g. banners/my.jpg -> https://<base>/storage/v1/object/public/banners/my.jpg
    return '$b/storage/v1/object/public/$trimmed';
  }
}
