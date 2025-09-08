import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDropoffScreen extends StatefulWidget {
  const AdminDropoffScreen({super.key});

  @override
  _AdminDropoffScreenState createState() => _AdminDropoffScreenState();
}

class _AdminDropoffScreenState extends State<AdminDropoffScreen> {
  final TextEditingController areaController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController contactController = TextEditingController();

  void openForm({DocumentSnapshot? existingDoc}) {
    if (existingDoc != null) {
      areaController.text = existingDoc['area'];
      addressController.text = existingDoc['address'];
      contactController.text = existingDoc['contact'];
    } else {
      areaController.clear();
      addressController.clear();
      contactController.clear();
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            existingDoc == null ? "Add Drop-Off Point" : "Edit Drop-Off Point"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: areaController,
                decoration: InputDecoration(labelText: "Area"),
              ),
              TextField(
                controller: addressController,
                decoration: InputDecoration(labelText: "Full Address"),
              ),
              TextField(
                controller: contactController,
                decoration: InputDecoration(labelText: "Contact Number"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (areaController.text.isNotEmpty &&
                  addressController.text.isNotEmpty &&
                  contactController.text.isNotEmpty) {
                final data = {
                  'area': areaController.text,
                  'address': addressController.text,
                  'contact': contactController.text,
                  'timestamp': FieldValue.serverTimestamp(),
                };

                if (existingDoc != null) {
                  await existingDoc.reference.update(data);
                } else {
                  await FirebaseFirestore.instance
                      .collection('dropoff_points')
                      .add(data);
                }

                Navigator.pop(context);
              }
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  void deletePoint(DocumentSnapshot doc) async {
    await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Drop-Off Points"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => openForm(),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dropoff_points')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.location_on, color: Colors.green),
                  title: Text(data['area'] ?? 'N/A'),
                  subtitle: Text((data['address'] ?? '') +
                      "\nPhone: ${data['contact'] ?? ''}"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => openForm(existingDoc: doc),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deletePoint(doc),
                      ),
                    ],
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
