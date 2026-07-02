// lib/screens/vendor/vendor_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Vendor Profile'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendors').where('userId', isEqualTo: user.uid).limit(1).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) {
            return const Center(child: Text('Vendor profile not found'));
          }
          final data = snap.data!.docs.first.data() as Map<String, dynamic>;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              CircleAvatar(radius: 40, backgroundColor: Colors.blue[100],
                  child: Icon(Icons.store, size: 40, color: Colors.blue[700])),
              const SizedBox(height: 12),
              Text(data['shopName'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Chip(label: Text((data['status'] ?? '').toUpperCase()),
                  backgroundColor: data['status'] == 'approved' ? Colors.green[100] : Colors.orange[100]),
              const SizedBox(height: 20),
              _row(Icons.email,      data['userEmail']   ?? ''),
              _row(Icons.phone,      data['phone']       ?? ''),
              _row(Icons.location_on, data['address']    ?? ''),
              _row(Icons.map,        data['serviceArea'] ?? ''),
            ]),
          );
        },
      ),
    );
  }

  Widget _row(IconData icon, String value) {
    if (value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: Colors.blue[700], size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ]),
    );
  }
}
