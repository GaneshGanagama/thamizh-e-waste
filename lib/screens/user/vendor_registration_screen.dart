// lib/screens/user/vendor_registration_screen.dart
//
// FIX: Registrations now go to 'vendor_requests' collection (not 'vendors').
// The VendorsTab in admin reads from 'vendor_requests' (status=pending).
// After admin approval the record is copied to 'vendors'.
// This prevents duplicate entries and aligns with VendorsTab approval logic.

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
  bool _submitting = false;
  bool _submitted = false;
  bool _capturingLocation = false;
  double? _latitude;
  double? _longitude;
  String? _locationLabel;

  final _locationService = LocationService();

  Future<void> _captureLocation() async {
    setState(() => _capturingLocation = true);
    try {
      final granted = await _locationService.ensurePermission();
      if (!granted) {
        _snack(
            'Location permission denied — enable it to add GPS to your listing');
        return;
      }
      final loc = await _locationService.captureLocation();
      if (loc == null) {
        _snack('Could not get your location. Try again.');
        return;
      }
      setState(() {
        _latitude = loc['latitude'] as double?;
        _longitude = loc['longitude'] as double?;
        _locationLabel = loc['readable'] as String?;
      });
    } finally {
      if (mounted) setState(() => _capturingLocation = false);
    }
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
    if (_shopCtrl.text.trim().isEmpty) {
      _snack('Enter shop name');
      return;
    }
    if (_ownerCtrl.text.trim().isEmpty) {
      _snack('Enter owner name');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _snack('Enter phone number');
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      _snack('Enter address');
      return;
    }
    if (_latitude == null || _longitude == null) {
      _snack(
          'Please capture your shop location (GPS) before submitting — this is how customers find you nearby.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Check if already applied in vendor_requests
      final existing = await FirebaseFirestore.instance
          .collection('vendor_requests')
          .where('userId', isEqualTo: user.uid)
          .get();
      if (existing.docs.isNotEmpty) {
        _snack('You have already submitted a vendor application.');
        setState(() => _submitting = false);
        return;
      }

      // Also check if already approved (in vendors collection)
      final approved = await FirebaseFirestore.instance
          .collection('vendors')
          .where('userId', isEqualTo: user.uid)
          .get();
      if (approved.docs.isNotEmpty) {
        _snack('You are already a registered vendor.');
        setState(() => _submitting = false);
        return;
      }

      // Write to vendor_requests (admin reviews from here)
      await FirebaseFirestore.instance.collection('vendor_requests').add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'shopName': _shopCtrl.text.trim(),
        'ownerName': _ownerCtrl.text.trim(),
        'contact': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'serviceArea': _areaCtrl.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      _snack('Error: $e');
      setState(() => _submitting = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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

  Widget _successView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Application Submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                  foregroundColor: Colors.white),
              child: const Text('Back to Home'),
            ),
          ]),
        ),
      );

  Widget _formView() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.green[700]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Register as a vendor to receive pickup assignments and earn commissions.',
                  style: TextStyle(fontSize: 13, color: Colors.green[800]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _field(_shopCtrl, 'Shop / Business Name *', Icons.store),
          const SizedBox(height: 14),
          _field(_ownerCtrl, 'Owner Name *', Icons.person),
          const SizedBox(height: 14),
          _field(_phoneCtrl, 'Phone Number *', Icons.phone,
              type: TextInputType.phone),
          const SizedBox(height: 14),
          _field(_addressCtrl, 'Full Address *', Icons.location_on,
              maxLines: 2),
          const SizedBox(height: 14),
          _field(
              _areaCtrl, 'Service Area (e.g. Chennai, Cuddalore)', Icons.map),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _capturingLocation ? null : _captureLocation,
            icon: _capturingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    _latitude != null ? Icons.check_circle : Icons.my_location,
                    color: _latitude != null ? Colors.green : null),
            label: Text(_latitude != null
                ? 'Location captured: $_locationLabel'
                : 'Capture Shop Location (GPS)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Submit Application',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
      );

  Widget _field(TextEditingController c, String label, IconData icon,
          {TextInputType type = TextInputType.text, int maxLines = 1}) =>
      TextField(
        controller: c,
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
