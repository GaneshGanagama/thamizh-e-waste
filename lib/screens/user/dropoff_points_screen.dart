import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class DropoffPointsScreen extends StatelessWidget {
  const DropoffPointsScreen({super.key});

  Future<void> _launchPhone(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (!await launchUrl(url)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Drop-Off Points"),
        backgroundColor: Colors.green[700],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('dropoffs').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading data"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No drop-off points available."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.green),
                  title: Text(data['area'] ?? 'Unknown Area'),
                  subtitle: Text(data['address'] ?? 'No address'),
                  trailing: IconButton(
                    icon: const Icon(Icons.phone, color: Colors.green),
                    onPressed: () => _launchPhone(data['contact'] ?? ''),
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
