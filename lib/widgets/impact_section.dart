// lib/widgets/impact_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class ImpactSection extends StatefulWidget {
  const ImpactSection({super.key});
  @override
  State<ImpactSection> createState() => _ImpactSectionState();
}

class _ImpactSectionState extends State<ImpactSection> {
  double _totalKg = 0;
  double _treesSaved = 0;
  double _waterLitres = 0;
  double _co2Kg = 0;
  int _completedCount = 0;

  bool _loaded = false;
  bool _hasError = false;

  // Simple rolling community milestone — every 1000kg is a new goal.
  // Purely a UI motivator, doesn't need its own Firestore field.
  static const double _milestoneStepKg = 1000;

  StreamSubscription? _impactSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _impactSub?.cancel();
    setState(() {
      _loaded = false;
      _hasError = false;
    });
    // Single read: the admin flows (requests_tab.dart, donations_tab.dart)
    // already increment this doc whenever a pickup/donation is completed,
    // so the Home page no longer needs to scan every pickup + donation.
    _impactSub = FirebaseFirestore.instance
        .collection('settings')
        .doc('total_impact')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final d = snap.data() ?? {};
      setState(() {
        _totalKg = (d['totalKg'] ?? 0).toDouble();
        _treesSaved = (d['treesSaved'] ?? 0).toDouble();
        _waterLitres = (d['waterLitres'] ?? 0).toDouble();
        _co2Kg = (d['co2Kg'] ?? 0).toDouble();
        _completedCount = (d['completedCount'] ?? 0).toInt();
        _loaded = true;
        _hasError = false;
      });
    }, onError: (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _hasError = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _impactSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = !_loaded;

    final currentMilestone =
        ((_totalKg / _milestoneStepKg).floor() + 1) * _milestoneStepKg;
    final progressToMilestone =
        (_totalKg % _milestoneStepKg) / _milestoneStepKg;
    final kgToGo = currentMilestone - _totalKg;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: Colors.green[700], size: 18),
              const SizedBox(width: 6),
              Text(
                'Our Collective Impact',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              const Spacer(),
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green[700],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (_hasError)
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Couldn't load impact data — check your connection or permissions.",
                    style: TextStyle(fontSize: 12, color: Colors.red[600]),
                  ),
                ),
                TextButton(
                  onPressed: _subscribe,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Retry', style: TextStyle(fontSize: 12)),
                ),
              ],
            )
          else
            Text(
              '$_completedCount recycling${_completedCount == 1 ? "" : "s"} completed · ${_totalKg.toStringAsFixed(0)} kg total',
              style: TextStyle(fontSize: 12, color: Colors.green[600]),
            ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ImpactTile(
                icon: Icons.park,
                value: _treesSaved,
                label: 'Trees Saved',
                color: Colors.green,
              ),
              _ImpactTile(
                icon: Icons.water_drop,
                value: _waterLitres,
                label: 'Litres Saved',
                color: Colors.blue,
              ),
              _ImpactTile(
                icon: Icons.cloud_off,
                value: _co2Kg,
                label: 'kg CO₂ Cut',
                color: Colors.teal,
              ),
            ],
          ),
          if (!_hasError && _loaded && _totalKg > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '${kgToGo.toStringAsFixed(0)} kg to ${currentMilestone.toStringAsFixed(0)} kg community goal',
                  style: TextStyle(fontSize: 11, color: Colors.green[700]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressToMilestone.clamp(0, 1),
                minHeight: 6,
                backgroundColor: Colors.green.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImpactTile extends StatelessWidget {
  final IconData icon;
  final double value;
  final String label;
  final Color color;

  const _ImpactTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        // Animates the number counting up/down whenever the underlying
        // Firestore doc changes, instead of a flat text swap.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, child) {
            return Text(
              animatedValue.toStringAsFixed(0),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
            );
          },
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}
