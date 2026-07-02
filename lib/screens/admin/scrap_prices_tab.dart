// lib/screens/admin/scrap_prices_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScrapPricesTab extends StatefulWidget {
  const ScrapPricesTab({super.key});

  @override
  State<ScrapPricesTab> createState() => _ScrapPricesTabState();
}

class _ScrapPricesTabState extends State<ScrapPricesTab> {
  final TextEditingController _typeCtrl = TextEditingController();
  final TextEditingController _minCtrl = TextEditingController();
  final TextEditingController _maxCtrl = TextEditingController();
  String _unit = 'kg';

  Future<void> _showSnack(String text) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addOrUpdateScrapPrice() async {
    final type = _typeCtrl.text.trim();
    final min = int.tryParse(_minCtrl.text.trim());
    final max = int.tryParse(_maxCtrl.text.trim());
    if (type.isEmpty || min == null || max == null) {
      _showSnack("Enter valid type & prices");
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('scrap_prices')
        .doc(type.toLowerCase().replaceAll(' ', '_'));

    try {
      await docRef.set({
        'wasteType': type,
        'minPrice': min,
        'maxPrice': max,
        'unit': _unit,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _typeCtrl.clear();
      _minCtrl.clear();
      _maxCtrl.clear();
      _showSnack("Saved scrap price");
    } catch (e) {
      _showSnack("Save failed: $e");
    }
  }

  Future<void> _deleteDoc(String id) async {
    await FirebaseFirestore.instance
        .collection('scrap_prices')
        .doc(id)
        .delete();
    _showSnack("Deleted");
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
                    controller: _typeCtrl,
                    decoration: const InputDecoration(labelText: "Type"))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _minCtrl,
                    decoration: const InputDecoration(labelText: "Min"),
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _maxCtrl,
                    decoration: const InputDecoration(labelText: "Max"),
                    keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            DropdownButton<String>(
                value: _unit,
                items: ['kg', 'piece']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _unit = v ?? 'kg')),
            const SizedBox(width: 8),
            ElevatedButton(
                onPressed: _addOrUpdateScrapPrice, child: const Text("Save"))
          ]),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('scrap_prices')
                .orderBy('wasteType')
                .snapshots(),
            builder: (c, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text("No scrap prices"));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final d = docs[i];
                  final data = d.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['wasteType'] ?? d.id),
                    subtitle: Text(
                        "₹${data['minPrice']} - ₹${data['maxPrice']} / ${data['unit']}"),
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
