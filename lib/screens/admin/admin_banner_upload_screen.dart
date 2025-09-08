import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AdminBannerUploadScreen extends StatefulWidget {
  const AdminBannerUploadScreen({super.key});

  @override
  State<AdminBannerUploadScreen> createState() =>
      _AdminBannerUploadScreenState();
}

class _AdminBannerUploadScreenState extends State<AdminBannerUploadScreen> {
  File? _image;
  bool _isUploading = false;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  Future<void> uploadImage() async {
    if (_image == null) return;

    setState(() => _isUploading = true);

    try {
      final fileName = 'banners/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(_image!);
      final downloadUrl = await ref.getDownloadURL();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Uploaded: $downloadUrl")),
      );

      setState(() {
        _image = null;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Upload failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Banner")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _image != null
                ? Image.file(_image!, height: 200)
                : Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(child: Text("No image selected")),
                  ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text("Pick Image"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : uploadImage,
              icon: const Icon(Icons.cloud_upload),
              label: _isUploading
                  ? const Text("Uploading...")
                  : const Text("Upload to Firebase"),
            ),
          ],
        ),
      ),
    );
  }
}
