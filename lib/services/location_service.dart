// lib/services/location_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  /// Returns true if permission is granted, false otherwise.
  Future<bool> ensurePermission() async {
    if (kIsWeb) {
      // On web, just try requesting – browser will prompt
      final perm = await Geolocator.requestPermission();
      return perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  /// Captures GPS position + reverse geocoded address.
  /// Returns a map:
  /// { latitude, longitude, readable, mapLink }
  Future<Map<String, dynamic>?> captureLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      String readable = '';
      if (!kIsWeb) {
        try {
          final marks =
              await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (marks.isNotEmpty) {
            final p = marks.first;
            readable =
                [p.name, p.locality, p.subAdministrativeArea, p.administrativeArea]
                    .where((s) => s != null && s.isNotEmpty)
                    .join(', ');
          }
        } catch (_) {
          // Geocoding may fail on emulators/web — use coordinates
        }
      }

      if (readable.isEmpty) {
        readable =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      }

      return {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'readable': readable,
        'mapLink':
            'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}',
      };
    } catch (e) {
      return null;
    }
  }
}
