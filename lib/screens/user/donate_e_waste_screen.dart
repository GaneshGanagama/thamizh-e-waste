// lib/screens/user/donate_e_waste_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:io' show Platform;

class DonateEWasteScreen extends StatefulWidget {
  const DonateEWasteScreen({super.key});

  @override
  State<DonateEWasteScreen> createState() => _DonateEWasteScreenState();
}

class _DonateEWasteScreenState extends State<DonateEWasteScreen> {
  // Address controllers (user editable)
  final TextEditingController houseController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController villageController = TextEditingController();
  final TextEditingController districtController = TextEditingController();
  final TextEditingController contactController = TextEditingController();

  // Image
  XFile? pickedImage;
  Uint8List? imageBytes;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Location
  Position? currentPosition;
  String readableAddress = "";
  Map<String, dynamic>? locationObject;
  bool _locating = false;

  // Submission state
  bool _submitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty) {
      contactController.text = user.phoneNumber!;
    }
  }

  @override
  void dispose() {
    houseController.dispose();
    areaController.dispose();
    villageController.dispose();
    districtController.dispose();
    contactController.dispose();
    super.dispose();
  }

  // -------------------------
  // Image picking (web-safe)
  // -------------------------
  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      setState(() {
        pickedImage = file;
        imageBytes = bytes;
      });
    } catch (e) {
      debugPrint('Image pick failed: $e');
      _showSnack('⚠️ Image pick failed: $e');
    }
  }

  // -------------------------
  // Supabase binary upload (works on web & native)
  // -------------------------
  Future<String?> _supabaseUpload(Uint8List bytes) async {
    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.2;
      });
      final url = await CloudinaryService.uploadImage(bytes,
          folder: 'ecomeel/donations');
      setState(() {
        _uploadProgress = 1.0;
        _isUploading = false;
      });
      if (url == null) debugPrint('Cloudinary upload returned null');
      return url;
    } catch (e) {
      debugPrint('Image upload error: \$e');
      setState(() {
        _isUploading = false;
      });
      return null;
    }
  }

  // -------------------------
  // Location: permission + capture + reverse geocoding
  // Returns a map like:
  // { 'latitude': ..., 'longitude': ..., 'readable': '...', 'mapLink': '...' }
  // -------------------------
  Future<Map<String, dynamic>?> _captureLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Location permission denied.');
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);

      String readable = '';
      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          readable =
              '${p.name ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}'
                  .replaceAll(RegExp(r',\s*$'), '');
        }
      } catch (e) {
        debugPrint('Reverse geocoding failed: $e');
        // It's okay to continue without readable address
      }

      final mapLink =
          'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';

      return {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'readable': readable,
        'mapLink': mapLink,
      };
    } catch (e) {
      debugPrint('Capture location error: $e');
      _showSnack('Error capturing location: $e');
      return null;
    }
  }

  // -------------------------
  // Submit donation (writes same structure as pickup)
  // -------------------------
  Future<void> _submitDonation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please log in first.');
      return;
    }

    // Basic validation
    if (houseController.text.trim().isEmpty ||
        areaController.text.trim().isEmpty ||
        villageController.text.trim().isEmpty ||
        districtController.text.trim().isEmpty) {
      _showSnack('Please fill all address fields.');
      return;
    }

    setState(() => _submitting = true);

    try {
      String imageUrl = '';

      // Upload image (if selected)
      if (pickedImage != null && imageBytes != null) {
        final url = await _supabaseUpload(imageBytes!);
        if (url != null) imageUrl = url;
      }

      // If location not captured earlier, attempt to capture now
      if (locationObject == null) {
        setState(() => _locating = true);
        final loc = await _captureLocation();
        setState(() => _locating = false);
        if (loc != null) {
          locationObject = loc;
          readableAddress = loc['readable'] ?? '';
        }
      }

      // Prepare Firestore document (matches pickup structure)
      final device = kIsWeb
          ? 'web'
          : (Platform.isAndroid
              ? 'android'
              : (Platform.isIOS ? 'ios' : 'unknown'));

      final doc = {
        'userId': user.uid,
        'userName': user.displayName ?? '',
        'userEmail': user.email ?? '',
        'userPhone': user.phoneNumber ?? '',
        'contactPhone': contactController.text.trim(),
        'address': {
          'house': houseController.text.trim(),
          'area': areaController.text.trim(),
          'village': villageController.text.trim(),
          'district': districtController.text.trim(),
          'readable': readableAddress,
        },
        'location': locationObject ??
            (currentPosition != null
                ? {
                    'latitude': currentPosition!.latitude,
                    'longitude': currentPosition!.longitude,
                    'readable': readableAddress,
                    'mapLink':
                        'https://www.google.com/maps/search/?api=1&query=${currentPosition!.latitude},${currentPosition!.longitude}'
                  }
                : null),
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Pending',
        'device': device,
      };

      // Success
      _showSnack('✅ Donation submitted. Thank you!');
      // Optionally navigate user to donations list or clear form
      setState(() {
        pickedImage = null;
        imageBytes = null;
        houseController.clear();
        areaController.clear();
        villageController.clear();
        districtController.clear();
        contactController.clear();
        readableAddress = '';
        locationObject = null;
        _uploadProgress = 0.0;
      });
    } catch (e, st) {
      debugPrint('Donation submit error: $e\n$st');
      _showSnack('Error submitting donation: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // -------------------------
  // Helpers
  // -------------------------
  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _onCaptureLocationPressed() async {
    setState(() => _locating = true);
    final loc = await _captureLocation();
    setState(() => _locating = false);
    if (loc != null) {
      setState(() {
        locationObject = loc;
        readableAddress = loc['readable'] ?? '';
        houseController.text = houseController.text.isEmpty
            ? (loc['readable'] ?? '')
            : houseController.text;
      });
      _showSnack('✅ Location captured');
    }
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donate E-Waste'),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your address details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            _textField('House / Building Name', houseController),
            const SizedBox(height: 10),
            _textField('Area / Street', areaController),
            const SizedBox(height: 10),
            _textField('Village / City', villageController),
            const SizedBox(height: 10),
            _textField('District', districtController),
            const SizedBox(height: 10),
            _textField('Contact Phone (for pickup)', contactController,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _locating ? null : _onCaptureLocationPressed,
              icon: const Icon(Icons.location_on),
              label: Text(_locating ? 'Capturing...' : 'Use Current Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              locationObject != null
                  ? '📍 ${locationObject!['readable'] ?? locationObject!['mapLink'] ?? 'Location captured'}'
                  : '📍 Location not captured',
            ),
            const SizedBox(height: 18),
            const Text('Upload Image (optional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isUploading ? null : _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: imageBytes == null
                    ? const Center(child: Icon(Icons.camera_alt, size: 40))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(imageBytes!, fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(height: 8),
            if (_isUploading)
              Column(
                children: [
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                    backgroundColor: Colors.grey[300],
                    color: Colors.green[700],
                  ),
                ],
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_submitting || _isUploading || _locating)
                    ? null
                    : _submitDonation,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.volunteer_activism),
                label: _submitting
                    ? const Text('Submitting...')
                    : const Text('Donate Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
