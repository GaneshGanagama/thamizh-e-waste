// lib/screens/user/user_awareness_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserAwarenessScreen extends StatelessWidget {
  const UserAwarenessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('E-Waste Awareness'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('awareness_posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lightbulb_outline, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No awareness posts yet', style: TextStyle(color: Colors.grey[500])),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.lightbulb, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(data['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                    ]),
                    const SizedBox(height: 10),
                    Text(data['body'] ?? '',
                        style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
