// lib/screens/vendor/vendor_dropoff_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VendorDropoffRequestsScreen extends StatelessWidget {
  const VendorDropoffRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Drop-off Requests'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('assignedVendorId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No drop-off requests assigned', style: TextStyle(color: Colors.grey[500])),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data   = docs[i].data() as Map<String, dynamic>;
              final name   = data['userName'] ?? 'User';
              final status = data['status']   ?? 'Pending';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.move_to_inbox, color: Colors.teal),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Status: $status'),
                  trailing: status != 'Collected'
                      ? TextButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('donations').doc(docs[i].id)
                                .update({'status': 'Collected'});
                          },
                          child: const Text('Mark Collected'),
                        )
                      : const Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
