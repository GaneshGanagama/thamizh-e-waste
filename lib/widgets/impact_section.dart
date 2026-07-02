// lib/widgets/impact_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImpactSection extends StatelessWidget {
  const ImpactSection({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX 1: Use StreamBuilder so numbers update in real-time
    //         when admin marks requests as Completed.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('impact_factors')
          .snapshots(),
      builder: (context, settingsSnap) {
        // Read impact multipliers (set by admin in Impact Settings tab)
        double treeFactor  = 30.0;  // kg of e-waste per tree saved
        double waterFactor = 5.0;   // litres saved per kg recycled
        double co2Factor   = 1.6;   // kg CO2 reduced per kg recycled

        if (settingsSnap.hasData && settingsSnap.data!.exists) {
          final d = settingsSnap.data!.data() as Map<String, dynamic>;
          treeFactor  = (d['tree']  ?? 30.0).toDouble();
          waterFactor = (d['water'] ?? 5.0).toDouble();
          co2Factor   = (d['co2']   ?? 1.6).toDouble();
        }

        // FIX 2: Listen to pickup_requests in real-time
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pickup_requests')
              // FIX 3: "Completed" matches what requests_tab.dart saves
              .where('status', isEqualTo: 'Completed')
              .snapshots(),
          builder: (context, pickupSnap) {

            // FIX 4: Also listen to donations that are "Collected"
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  // donations_tab.dart saves 'Collected' for completed donations
                  .where('status', isEqualTo: 'Collected')
                  .snapshots(),
              builder: (context, donationSnap) {

                double totalKg = 0;

                // Count kg from completed pickup requests (items array)
                if (pickupSnap.hasData) {
                  for (final doc in pickupSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final items = data['items'] as List<dynamic>? ?? [];
                    for (final it in items) {
                      totalKg += (it['weight'] as num? ?? 0).toDouble();
                    }
                  }
                }

                // Count kg from collected donations
                // Donations don't have an items array — each donation is
                // treated as 1 kg by default, or use a 'weight' field if present
                if (donationSnap.hasData) {
                  for (final doc in donationSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    // If admin added a weight field use it, otherwise count 1 kg
                    final w = (data['weight'] as num? ?? 1).toDouble();
                    totalKg += w;
                  }
                }

                // Show loading only while both streams are waiting
                final isLoading =
                    pickupSnap.connectionState == ConnectionState.waiting ||
                    donationSnap.connectionState == ConnectionState.waiting;

                // Calculate impact numbers
                final treesCount = treeFactor > 0
                    ? (totalKg / treeFactor).toStringAsFixed(0)
                    : '0';
                final waterLitres =
                    (totalKg * waterFactor).toStringAsFixed(0);
                final co2Kg =
                    (totalKg * co2Factor).toStringAsFixed(0);
                final totalItems =
                    (pickupSnap.data?.docs.length ?? 0) +
                    (donationSnap.data?.docs.length ?? 0);

                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.eco,
                              color: Colors.green[700], size: 18),
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
                      Text(
                        '$totalItems recycling${totalItems == 1 ? "" : "s"} completed · ${totalKg.toStringAsFixed(0)} kg total',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green[600]),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: [
                          _ImpactTile(
                            icon: Icons.park,
                            value: treesCount,
                            label: 'Trees Saved',
                            color: Colors.green,
                          ),
                          _ImpactTile(
                            icon: Icons.water_drop,
                            value: waterLitres,
                            label: 'Litres Saved',
                            color: Colors.blue,
                          ),
                          _ImpactTile(
                            icon: Icons.cloud_off,
                            value: co2Kg,
                            label: 'kg CO₂ Cut',
                            color: Colors.teal,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ImpactTile extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;

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
        Text(
          value,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}
