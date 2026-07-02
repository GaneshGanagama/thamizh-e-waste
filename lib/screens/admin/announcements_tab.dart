// lib/screens/admin/announcements_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({super.key});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();

  Future<void> _postAnnouncement() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty && body.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter title or body")));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('info_posts').add({
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp()
      });
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Posting failed: $e")));
    }
  }

  Future<void> _deleteDoc(String id) async {
    await FirebaseFirestore.instance.collection('info_posts').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(children: [
            TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: "Title")),
            const SizedBox(height: 6),
            TextField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(labelText: "Body")),
            const SizedBox(height: 6),
            ElevatedButton(
                onPressed: _postAnnouncement, child: const Text("Post"))
          ]),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('info_posts')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (c, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text("No announcements"));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final d = docs[i];
                  final data = d.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['title'] ?? "Update"),
                    subtitle: Text(data['body'] ?? ""),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDoc(d.id)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
