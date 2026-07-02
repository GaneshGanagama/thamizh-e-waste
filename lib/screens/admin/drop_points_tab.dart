import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class DropPointsTab extends StatefulWidget {
  const DropPointsTab({super.key});

  @override
  State<DropPointsTab> createState() => _DropPointsTabState();
}

class _DropPointsTabState extends State<DropPointsTab> {
  final TextEditingController _areaCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _lngCtrl = TextEditingController();

  Future<void> _showSnack(String text) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addDropPoint() async {
    if (_areaCtrl.text.isEmpty ||
        _addressCtrl.text.isEmpty ||
        _contactCtrl.text.isEmpty) {
      _showSnack("Fill all details");
      return;
    }

    try {
      final Map<String, dynamic> payload = {
        'area': _areaCtrl.text,
        'address': _addressCtrl.text,
        'contact': _contactCtrl.text,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_latCtrl.text.trim().isNotEmpty && _lngCtrl.text.trim().isNotEmpty) {
        final lat = double.tryParse(_latCtrl.text.trim());
        final lng = double.tryParse(_lngCtrl.text.trim());
        if (lat != null && lng != null) {
          payload['latitude'] = lat;
          payload['longitude'] = lng;
        }
      }

      await FirebaseFirestore.instance.collection('dropoffs').add(payload);

      _areaCtrl.clear();
      _addressCtrl.clear();
      _contactCtrl.clear();
      _latCtrl.clear();
      _lngCtrl.clear();
      _showSnack("Drop point added");
    } catch (e) {
      _showSnack("Add failed: $e");
    }
  }

  Future<void> _captureCoordinates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _showSnack('Location services disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return _showSnack('Location permission denied permanently');
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _latCtrl.text = pos.latitude.toString();
      _lngCtrl.text = pos.longitude.toString();
      _showSnack('Coordinates captured');
    } catch (e) {
      _showSnack('Unable to capture coordinates: $e');
    }
  }

  Future<void> _deleteDoc(String id) async {
    await FirebaseFirestore.instance.collection('dropoffs').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(children: [
            TextField(
                controller: _areaCtrl,
                decoration: const InputDecoration(labelText: "Area")),
            const SizedBox(height: 6),
            TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: "Address")),
            const SizedBox(height: 6),
            TextField(
                controller: _contactCtrl,
                decoration: const InputDecoration(labelText: "Contact Number")),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _latCtrl,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lngCtrl,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              IconButton(
                tooltip: 'Use current location',
                icon: const Icon(Icons.my_location),
                onPressed: _captureCoordinates,
              )
            ]),
            const SizedBox(height: 6),
            ElevatedButton(
                onPressed: _addDropPoint, child: const Text("Add Drop Point"))
          ]),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('dropoffs') // ✅ consistent
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (c, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text("No drop points"));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final d = docs[i];
                  final data = d.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['area'] ?? "Area"),
                    subtitle: Text(
                        "${data['address'] ?? ''}\n📞 ${data['contact'] ?? ''}"),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteDoc(d.id),
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
