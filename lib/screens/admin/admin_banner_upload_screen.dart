// lib/screens/admin/admin_banner_upload_screen.dart
//
// FIX: Was using dart:io File which crashes on Web.
// Now uses readAsBytes() for both web and mobile.

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBannerUploadScreen extends StatefulWidget {
  const AdminBannerUploadScreen({super.key});

  @override
  State<AdminBannerUploadScreen> createState() =>
      _AdminBannerUploadScreenState();
}

class _AdminBannerUploadScreenState extends State<AdminBannerUploadScreen> {
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isUploading = false;

  Future<void> pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name;
    });
  }

  Future<void> uploadImage() async {
    if (_imageBytes == null) return;
    setState(() => _isUploading = true);

    try {
      final fileName =
          'banners/${DateTime.now().millisecondsSinceEpoch}_${_imageName ?? "banner.jpg"}';
      final ref = FirebaseStorage.instance.ref(fileName);

      await ref.putData(
        _imageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('banners').add({
        'imageUrl': downloadUrl,
        'active': true,
        'order': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ Banner uploaded')));

      setState(() {
        _imageBytes = null;
        _imageName = null;
        _isUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('❌ Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Banner'),
        backgroundColor: Colors.green[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _imageBytes != null
                ? Image.memory(_imageBytes!, height: 200)
                : Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(child: Text('No image selected')),
                  ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Pick Image'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : uploadImage,
              icon: const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? 'Uploading...' : 'Upload Banner'),
            ),
          ],
        ),
      ),
    );
  }
}
