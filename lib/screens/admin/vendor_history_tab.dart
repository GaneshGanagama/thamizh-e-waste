import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VendorHistoryTab extends StatelessWidget {
  const VendorHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendor_history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No vendor history yet"));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final action = data['action'] ?? 'unknown';
              final color = action == 'approved' ? Colors.green : Colors.red;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(
                    action == 'approved' ? Icons.check_circle : Icons.cancel,
                    color: color,
                  ),
                  title: Text("Vendor: ${data['userId'] ?? 'Unknown'}"),
                  subtitle: Text(
                    "Action: $action\nTime: ${(data['timestamp'] as Timestamp?)?.toDate().toString().substring(0, 19) ?? ''}",
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
