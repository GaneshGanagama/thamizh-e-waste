// lib/screens/admin/impact_settings_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImpactSettingsTab extends StatefulWidget {
  const ImpactSettingsTab({super.key});

  @override
  State<ImpactSettingsTab> createState() => _ImpactSettingsTabState();
}

class _ImpactSettingsTabState extends State<ImpactSettingsTab> {
  final TextEditingController _treeFactorCtrl =
      TextEditingController(text: "30");
  final TextEditingController _waterFactorCtrl =
      TextEditingController(text: "5");
  final TextEditingController _co2FactorCtrl =
      TextEditingController(text: "1.6");

  @override
  void initState() {
    super.initState();
    _loadImpactFactors();
  }

  Future<void> _loadImpactFactors() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('impact_factors')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _treeFactorCtrl.text =
            (data['tree']?.toString() ?? _treeFactorCtrl.text);
        _waterFactorCtrl.text =
            (data['water']?.toString() ?? _waterFactorCtrl.text);
        _co2FactorCtrl.text = (data['co2']?.toString() ?? _co2FactorCtrl.text);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _saveImpactFactors() async {
    final tree = double.tryParse(_treeFactorCtrl.text) ?? 30.0;
    final water = double.tryParse(_waterFactorCtrl.text) ?? 5.0;
    final co2 = double.tryParse(_co2FactorCtrl.text) ?? 1.6;
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('impact_factors')
          .set({
        'tree': tree,
        'water': water,
        'co2': co2,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Impact factors saved")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Save failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Impact Factors",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
            controller: _treeFactorCtrl,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: "Kg per Tree (e.g. 30)")),
        const SizedBox(height: 8),
        TextField(
            controller: _waterFactorCtrl,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: "Liters per Kg (e.g. 5)")),
        const SizedBox(height: 8),
        TextField(
            controller: _co2FactorCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: "CO₂ reduced per Kg (e.g. 1.6)")),
        const SizedBox(height: 12),
        ElevatedButton(
            onPressed: _saveImpactFactors,
            child: const Text("Save Impact Factors"))
      ]),
    );
  }
}
