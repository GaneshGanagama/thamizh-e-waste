// lib/screens/user/profile_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  String currentLocation = 'Tap to update location';
  final phoneController = TextEditingController();

  bool _loading = true;
  bool _loadError = false;
  bool _locationBusy = false;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> fetchUserData() async {
    if (user == null) {
      setState(() {
        _loading = false;
        _loadError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadError = false;
    });

    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user!.uid);

      var doc = await docRef.get().timeout(const Duration(seconds: 12));

      // If the user doc doesn't exist yet (e.g. brand-new Google sign-in
      // where creation hadn't finished), create a minimal one instead of
      // hanging forever on a doc that will never appear.
      if (!doc.exists) {
        await docRef.set({
          'uid': user!.uid,
          'name': user!.displayName ?? '',
          'email': user!.email ?? '',
          'phone': user!.phoneNumber ?? '',
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        doc = await docRef.get().timeout(const Duration(seconds: 12));
      }

      if (!mounted) return;

      setState(() {
        userData = doc.data() ?? {};
        phoneController.text = userData?['phone'] ?? '';
        final lat = userData?['latitude'];
        final lng = userData?['longitude'];
        if (lat != null && lng != null) {
          currentLocation =
              '${(lat as num).toStringAsFixed(4)}, ${(lng as num).toStringAsFixed(4)}';
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<Position?> _getLocationWithPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Location services are disabled. Please enable them.');
      return null;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnack('Location permission denied.');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnack(
          'Location permission permanently denied. Enable in device settings.');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } on TimeoutException {
      _showSnack('Could not get your location in time. Try again.');
      return null;
    } catch (e) {
      _showSnack('Location error: $e');
      return null;
    }
  }

  Future<void> updatePhone() async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'phone': phoneController.text.trim()}).timeout(
              const Duration(seconds: 10));
      _showSnack('Phone number updated');
    } catch (e) {
      _showSnack('Could not update phone: $e');
    }
  }

  Future<void> updateLocation() async {
    if (_locationBusy) return;
    setState(() => _locationBusy = true);

    final pos = await _getLocationWithPermission();

    if (pos == null) {
      if (mounted) setState(() => _locationBusy = false);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
        'latitude': pos.latitude,
        'longitude': pos.longitude
      }).timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          currentLocation =
              '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });
        _showSnack('Location updated');
      }
    } catch (e) {
      _showSnack('Could not save location: $e');
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.green[700],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError || userData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            const Text('Could not load your profile.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: fetchUserData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green,
                  child:
                      const Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(userData!['name'] ?? 'User',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Chip(
                  label: Text(userData!['role'] ?? 'User',
                      style: const TextStyle(color: Colors.white)),
                  backgroundColor: Colors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(children: [
            const Icon(Icons.email, color: Colors.grey),
            const SizedBox(width: 10),
            Text(user?.email ?? 'No Email'),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: const Icon(Icons.phone),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save, color: Colors.green),
                onPressed: updatePhone,
                tooltip: 'Save phone',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      Text(currentLocation, overflow: TextOverflow.ellipsis)),
              _locationBusy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.blue),
                      onPressed: updateLocation,
                      tooltip: 'Update location',
                    ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }
}
