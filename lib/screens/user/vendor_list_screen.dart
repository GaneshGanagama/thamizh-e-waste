// lib/screens/user/vendor_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class VendorListScreen extends StatelessWidget {
  const VendorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Vendor Partners'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendors')
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.store, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No approved vendors yet', style: TextStyle(color: Colors.grey[500])),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final name    = data['shopName'] ?? 'Vendor';
              final address = data['address']  ?? '';
              final phone   = data['phone']    ?? '';
              final area    = data['serviceArea'] ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[50],
                    child: Icon(Icons.store, color: Colors.green[700]),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (address.isNotEmpty) Text(address, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    if (area.isNotEmpty) Text('Serves: $area', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                  isThreeLine: area.isNotEmpty,
                  trailing: phone.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () async {
                            final uri = Uri.parse('tel:$phone');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          })
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
