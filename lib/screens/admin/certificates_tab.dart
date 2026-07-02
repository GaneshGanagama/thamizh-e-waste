// lib/screens/admin/certificates_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

class CertificatesTab extends StatefulWidget {
  const CertificatesTab({super.key});

  @override
  State<CertificatesTab> createState() => _CertificatesTabState();
}

class _CertificatesTabState extends State<CertificatesTab> {
  final TextEditingController _userCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;

  Future<void> _showSnack(String text) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _uploadCertificate() async {
    final userName = _userCtrl.text.trim();
    if (userName.isEmpty) {
      _showSnack("Enter user name");
      return;
    }

    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final fileName =
          'certificates/${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      final bytes = await picked.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('certificates').add({
        'userName': userName,
        'url': url,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _userCtrl.clear();
      _showSnack("Certificate uploaded");
    } catch (e) {
      _showSnack("Upload failed: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteDoc(String id) async {
    await FirebaseFirestore.instance
        .collection('certificates')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(children: [
            Expanded(
                child: TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(labelText: "User Name"))),
            const SizedBox(width: 8),
            ElevatedButton(
                onPressed: _uploading ? null : _uploadCertificate,
                child: Text(_uploading ? "Uploading..." : "Upload"))
          ]),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('certificates')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (c, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text("No certificates"));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final d = docs[i];
                  final data = d.data() as Map<String, dynamic>;
                  return ListTile(
                    leading:
                        const Icon(Icons.picture_as_pdf, color: Colors.green),
                    title: Text(data['userName'] ?? "Unknown"),
                    subtitle: Text(data['url'] ?? "No file"),
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
