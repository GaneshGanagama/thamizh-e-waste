// lib/screens/user/profile_screen.dart
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
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          userData = doc.data();
          phoneController.text = userData?['phone'] ?? '';
          final lat = userData?['latitude'];
          final lng = userData?['longitude'];
          if (lat != null && lng != null) {
            currentLocation = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
          }
        });
      }
    }
  }

  // FIX: request permission before calling geolocator
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
      _showSnack('Location permission permanently denied. Enable in device settings.');
      return null;
    }
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> updatePhone() async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'phone': phoneController.text.trim(),
    });
    _showSnack('Phone number updated');
  }

  Future<void> updateLocation() async {
    final pos = await _getLocationWithPermission();
    if (pos == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
    });
    if (mounted) {
      setState(() {
        currentLocation =
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      });
    }
    _showSnack('Location updated');
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
      body: userData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                          child: const Icon(Icons.person, size: 50, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(userData!['name'] ?? 'User',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                    Text(user!.email ?? 'No Email'),
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
                          child: Text(currentLocation,
                              overflow: TextOverflow.ellipsis)),
                      IconButton(
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
            ),
    );
  }
}
