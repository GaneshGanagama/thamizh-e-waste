// lib/screens/admin/banners_tab.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart' show rootBundle;

class BannersTab extends StatefulWidget {
  const BannersTab({super.key});

  @override
  State<BannersTab> createState() => _BannersTabState();
}

class _BannersTabState extends State<BannersTab> {
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;

  /// List of default asset banners (make sure these exist in pubspec.yaml)
  final List<String> defaultBanners = [
    "assets/banners/banner1.jpg",
    "assets/banners/banner2.jpg",
    "assets/banners/banner3.jpg",
  ];

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _showSnack(String text) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Upload image from gallery
  Future<void> _pickAndUploadBanner() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final fileName =
          'banners/${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      final bytes = await picked.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final url = await ref.getDownloadURL();
      await _saveBannerDoc(url);

      _showSnack("✅ Banner uploaded");
    } catch (e) {
      _showSnack("Upload failed: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Upload default asset banners
  Future<void> _uploadDefaultBanners() async {
    setState(() => _uploading = true);
    try {
      for (final assetPath in defaultBanners) {
        final fileName =
            "banners/default_${assetPath.split('/').last}"; // e.g. default_banner1.jpg
        final ref = FirebaseStorage.instance.ref().child(fileName);

        // If file already exists in storage skip uploading (safe-check)
        bool alreadyExists = false;
        try {
          await ref.getDownloadURL();
          alreadyExists = true;
        } catch (_) {
          alreadyExists = false;
        }

        if (alreadyExists) {
          _showSnack("Already uploaded: ${assetPath.split('/').last}");
          continue; // skip if already uploaded
        }

        final byteData = await rootBundle.load(assetPath);
        final Uint8List bytes = byteData.buffer.asUint8List();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        final url = await ref.getDownloadURL();
        await _saveBannerDoc(url);
        _showSnack("Uploaded: ${assetPath.split('/').last}");
      }
    } catch (e) {
      _showSnack("Default upload failed: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Save Firestore banner doc with order
  Future<void> _saveBannerDoc(String url) async {
    int newOrder = 0;
    final q = await FirebaseFirestore.instance
        .collection('banners')
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      newOrder = _toInt((q.docs.first.data())['order']) + 1;
    }
    await FirebaseFirestore.instance.collection('banners').add({
      'imageUrl': url,
      'order': newOrder,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _moveBanner(DocumentSnapshot doc, bool moveUp) async {
    try {
      final currentOrder =
          _toInt((doc.data() as Map<String, dynamic>)['order']);
      final col = FirebaseFirestore.instance.collection('banners');

      QuerySnapshot neighborQuery;
      if (moveUp) {
        neighborQuery = await col
            .where('order', isLessThan: currentOrder)
            .orderBy('order', descending: true)
            .limit(1)
            .get();
      } else {
        // <-- corrected here: use descending: false (ascending isn't a valid named param)
        neighborQuery = await col
            .where('order', isGreaterThan: currentOrder)
            .orderBy('order', descending: false)
            .limit(1)
            .get();
      }

      if (neighborQuery.docs.isEmpty) {
        _showSnack(moveUp ? "Already at top" : "Already at bottom");
        return;
      }

      final neighborDoc = neighborQuery.docs.first;
      final neighborOrder =
          _toInt((neighborDoc.data() as Map<String, dynamic>)['order']);

      final batch = FirebaseFirestore.instance.batch();
      batch.update(doc.reference, {'order': neighborOrder});
      batch.update(neighborDoc.reference, {'order': currentOrder});
      await batch.commit();

      _showSnack("Reordered");
    } catch (e) {
      _showSnack("Reorder failed: $e");
    }
  }

  Future<void> _deleteBanner(String id) async {
    try {
      await FirebaseFirestore.instance.collection('banners').doc(id).delete();
      _showSnack("Deleted");
    } catch (e) {
      _showSnack("Delete failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _uploading ? null : _pickAndUploadBanner,
                icon: const Icon(Icons.upload),
                label: Text(_uploading ? "Uploading..." : "Upload Banner"),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _uploading ? null : _uploadDefaultBanners,
                icon: const Icon(Icons.file_copy),
                label: Text(_uploading ? "Uploading..." : "Upload Defaults"),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('banners')
                .orderBy('order')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text("Error: ${snap.error}"));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text("No banners uploaded"));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final d = docs[i];
                  final data = d.data() as Map<String, dynamic>;
                  final imageUrl = (data['imageUrl'] ?? '').toString();
                  final order = _toInt(data['order']);
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: ListTile(
                      leading: imageUrl.isNotEmpty
                          ? Image.network(imageUrl,
                              width: 90,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image))
                          : const Icon(Icons.image),
                      title: Text(imageUrl.isNotEmpty ? imageUrl : "Banner"),
                      subtitle: Text("Order: $order"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward,
                                color: Colors.blue),
                            onPressed: () => _moveBanner(d, true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward,
                                color: Colors.blue),
                            onPressed: () => _moveBanner(d, false),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteBanner(d.id),
                          ),
                        ],
                      ),
                    ),
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
