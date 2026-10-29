// lib/screens/user/vendor_registration_screen.dart
//
// Vendor registration with mandatory GPS location.
// Requests are saved to vendor_requests.
// Approved vendors are stored in vendors.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/location_service.dart';

class VendorRegistrationScreen extends StatefulWidget {
  const VendorRegistrationScreen({super.key});

  @override
  State<VendorRegistrationScreen> createState() =>
      _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<VendorRegistrationScreen> {
  final _shopCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();

  final _locationService = LocationService();

  bool _submitting = false;
  bool _submitted = false;
  bool _capturingLocation = false;

  double? _latitude;
  double? _longitude;
  String? _locationLabel;

  bool get _hasValidLocation {
    final lat = _latitude;
    final lng = _longitude;

    return lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  Future<void> _captureLocation() async {
    if (_capturingLocation || _submitting) return;

    setState(() {
      _capturingLocation = true;
      _latitude = null;
      _longitude = null;
      _locationLabel = null;
    });

    try {
      final granted = await _locationService.ensurePermission();

      if (!mounted) return;

      if (!granted) {
        _snack(
          'Location permission is required. Enable location permission and try again.',
        );
        return;
      }

      final loc = await _locationService.captureLocation();

      if (!mounted) return;

      if (loc == null) {
        _snack(
          'Could not capture your shop location. Check GPS and try again.',
        );
        return;
      }

      final lat = _toDouble(loc['latitude']);
      final lng = _toDouble(loc['longitude']);
      final readable = loc['readable']?.toString();

      if (lat == null ||
          lng == null ||
          !lat.isFinite ||
          !lng.isFinite ||
          lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180) {
        _snack('Invalid GPS coordinates. Please capture your location again.');
        return;
      }

      setState(() {
        _latitude = lat;
        _longitude = lng;
        _locationLabel = readable != null && readable.trim().isNotEmpty
            ? readable
            : '$lat, $lng';
      });

      _snack('Shop location captured successfully.');
    } catch (e) {
      if (mounted) {
        _snack('Location capture failed. Please try again.');
        debugPrint('Vendor location capture error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _capturingLocation = false);
      }
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  @override
  void dispose() {
    _shopCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _submitted) return;

    if (_shopCtrl.text.trim().isEmpty) {
      _snack('Enter shop name.');
      return;
    }

    if (_ownerCtrl.text.trim().isEmpty) {
      _snack('Enter owner name.');
      return;
    }

    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _snack('Enter phone number.');
      return;
    }

    if (_addressCtrl.text.trim().isEmpty) {
      _snack('Enter the full shop address.');
      return;
    }

    // LOCATION IS MANDATORY.
    // Do not submit if coordinates are missing or invalid.
    if (!_hasValidLocation) {
      _snack(
        'Shop location is required. Tap "Capture Shop Location (GPS)" before submitting.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Please log in again before submitting your application.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // Check for an existing vendor application.
      final existing = await firestore
          .collection('vendor_requests')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (!mounted) return;

      if (existing.docs.isNotEmpty) {
        _snack('You have already submitted a vendor application.');
        return;
      }

      // Check whether this user is already an approved vendor.
      // Check the document ID as well as userId for compatibility.
      final approvedById =
          await firestore.collection('vendors').doc(user.uid).get();

      if (!mounted) return;

      final approvedByUserId = await firestore
          .collection('vendors')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (!mounted) return;

      if (approvedById.exists || approvedByUserId.docs.isNotEmpty) {
        _snack('You are already a registered vendor.');
        return;
      }

      // Recheck location immediately before writing to Firestore.
      if (!_hasValidLocation) {
        _snack('Valid shop GPS coordinates are required.');
        return;
      }

      // Preserve the existing Firestore collection and field names.
      await firestore.collection('vendor_requests').add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'shopName': _shopCtrl.text.trim(),
        'ownerName': _ownerCtrl.text.trim(),
        'contact': phone,
        'address': _addressCtrl.text.trim(),
        'serviceArea': _areaCtrl.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'locationLabel': _locationLabel ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() => _submitted = true);
      _snack('Vendor application submitted successfully.');
    } catch (e, stackTrace) {
      debugPrint('Vendor registration error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _snack(
          'Could not submit your application. Check your connection and permissions, then try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Join as Vendor'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _submitted ? _successView() : _formView(),
    );
  }

  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Application Submitted!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Our team will review your application and contact you within 2-3 business days.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.green[700],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Register as a vendor to receive pickup assignments and earn commissions.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _field(
            _shopCtrl,
            'Shop / Business Name *',
            Icons.store,
          ),
          const SizedBox(height: 14),

          _field(
            _ownerCtrl,
            'Owner Name *',
            Icons.person,
          ),
          const SizedBox(height: 14),

          _field(
            _phoneCtrl,
            'Phone Number *',
            Icons.phone,
            type: TextInputType.phone,
          ),
          const SizedBox(height: 14),

          _field(
            _addressCtrl,
            'Full Address *',
            Icons.location_on,
            maxLines: 2,
          ),
          const SizedBox(height: 14),

          _field(
            _areaCtrl,
            'Service Area (e.g. Chennai, Cuddalore)',
            Icons.map,
          ),
          const SizedBox(height: 20),

          // Mandatory GPS section.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _hasValidLocation ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasValidLocation
                    ? Colors.green.shade300
                    : Colors.orange.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _hasValidLocation
                          ? Icons.check_circle
                          : Icons.location_on,
                      color: _hasValidLocation
                          ? Colors.green[700]
                          : Colors.orange[800],
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Shop GPS Location *',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _hasValidLocation
                      ? 'Location captured successfully.'
                      : 'Required: capture the actual shop location before submitting.',
                  style: const TextStyle(fontSize: 13),
                ),
                if (_hasValidLocation) ...[
                  const SizedBox(height: 8),
                  Text(
                    _locationLabel ?? 'Location captured',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Latitude: $_latitude\nLongitude: $_longitude',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _capturingLocation || _submitting
                        ? null
                        : _captureLocation,
                    icon: _capturingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _hasValidLocation
                                ? Icons.refresh
                                : Icons.my_location,
                          ),
                    label: Text(
                      _capturingLocation
                          ? 'Capturing location...'
                          : _hasValidLocation
                              ? 'Capture Location Again'
                              : 'Capture Shop Location (GPS)',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting || _capturingLocation ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Application',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '* Required fields. A valid GPS location is mandatory.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
