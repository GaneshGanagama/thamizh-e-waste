import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class PickupRequestScreen extends StatefulWidget {
  const PickupRequestScreen({super.key});

  @override
  State<PickupRequestScreen> createState() => _PickupRequestScreenState();
}

class _PickupRequestScreenState extends State<PickupRequestScreen> {
  final TextEditingController addressController = TextEditingController();
  final List<String> wasteTypes = [
    'Mobile Phone',
    'Laptop',
    'TV',
    'Battery',
    'Others'
  ];
  String? selectedWasteType;
  File? selectedImage;
  Position? currentPosition;

  Future<void> pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Location permission denied")),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );

    setState(() {
      currentPosition = position;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              "📍 Location Captured: ${position.latitude}, ${position.longitude}")),
    );
  }

  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}";
      final ref =
          FirebaseStorage.instance.ref().child("pickup_images/$fileName");
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Image upload error: $e");
      return null;
    }
  }

  Future<void> submitRequest() async {
    if (selectedWasteType == null ||
        addressController.text.isEmpty ||
        currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❗ Please fill all fields")),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      String? imageUrl;

      if (selectedImage != null) {
        imageUrl = await uploadImage(selectedImage!);
      }

      await FirebaseFirestore.instance.collection('pickup_requests').add({
        'wasteType': selectedWasteType,
        'address': addressController.text,
        'latitude': currentPosition!.latitude,
        'longitude': currentPosition!.longitude,
        'timestamp': DateTime.now(),
        'status': 'Pending',
        'userEmail': user?.email ?? 'Anonymous',
        'userName': user?.displayName ?? 'Unknown',
        'imageUrl': imageUrl ?? '',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Pickup request submitted")),
      );

      setState(() {
        selectedWasteType = null;
        addressController.clear();
        selectedImage = null;
        currentPosition = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request E-Waste Pickup"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Waste Type",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedWasteType,
              hint: const Text("Choose one"),
              items: wasteTypes
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => selectedWasteType = value),
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Pickup Address",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: addressController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Enter your address",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Upload Image (optional)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: selectedImage == null
                    ? const Center(child: Icon(Icons.camera_alt, size: 40))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(selectedImage!.path,
                            fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: getCurrentLocation,
              icon: const Icon(Icons.location_on),
              label: const Text("Use Current Location"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: submitRequest,
                  icon: const Icon(Icons.send),
                  label: const Text("Submit Request"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
