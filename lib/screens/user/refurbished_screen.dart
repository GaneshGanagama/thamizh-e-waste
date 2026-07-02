// lib/screens/user/refurbished_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class RefurbishedScreen extends StatelessWidget {
  const RefurbishedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Refurbished Items'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('refurbished_items')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.build_circle, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('No refurbished items listed yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[500])),
              const SizedBox(height: 8),
              Text('Check back soon!', style: TextStyle(color: Colors.grey[400])),
            ]));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12,
              mainAxisSpacing: 12, childAspectRatio: 0.75,
            ),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data  = docs[i].data() as Map<String, dynamic>;
              final name  = data['name']  ?? 'Item';
              final price = data['price'] ?? 0;
              final desc  = data['description'] ?? '';
              final img   = data['imageUrl'] ?? '';
              final link  = data['contactLink'] ?? '';
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: img.isNotEmpty
                        ? Image.network(img, height: 120, width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                height: 120, color: Colors.grey[200],
                                child: const Icon(Icons.image, size: 40, color: Colors.grey)))
                        : Container(height: 120, color: Colors.grey[200],
                            child: const Icon(Icons.build_circle, size: 40, color: Colors.grey)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (desc.isNotEmpty)
                        Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('₹$price', style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green[700], fontSize: 14)),
                      if (link.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            final uri = Uri.parse(link);
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text('Contact Seller', style: TextStyle(fontSize: 11)),
                        ),
                    ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
