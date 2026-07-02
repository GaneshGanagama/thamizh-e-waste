import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AwarenessTab extends StatefulWidget {
  const AwarenessTab({super.key});

  @override
  State<AwarenessTab> createState() => _AwarenessTabState();
}

class _AwarenessTabState extends State<AwarenessTab> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  void _openForm({DocumentSnapshot? existingDoc}) {
    if (existingDoc != null) {
      final data = existingDoc.data() as Map<String, dynamic>;
      titleController.text = data['title'] ?? '';
      bodyController.text = data['body'] ?? '';
    } else {
      titleController.clear();
      bodyController.clear();
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            Text(existingDoc == null ? "Add Awareness Post" : "Edit Awareness"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: "Description"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty ||
                  bodyController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill all fields")));
                return;
              }

              final data = {
                'title': titleController.text.trim(),
                'body': bodyController.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              };

              if (existingDoc != null) {
                await existingDoc.reference.update(data);
              } else {
                await FirebaseFirestore.instance
                    .collection('awareness_posts')
                    .add(data);
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("Are you sure you want to delete this post?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () async {
              await doc.reference.delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green[700],
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text("Add Post"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('awareness_posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No awareness posts yet."));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading:
                      const Icon(Icons.lightbulb_outline, color: Colors.green),
                  title: Text(data['title'] ?? "Untitled"),
                  subtitle: Text(data['body'] ?? "",
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _openForm(existingDoc: doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(doc),
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
