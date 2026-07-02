// lib/screens/user/rewards_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Rewards'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};
          final points = (data['points'] as num? ?? 0).toInt();
          final totalKg = (data['totalRecycledWeight'] as num? ?? 0).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Points card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green[700]!, Colors.green[400]!]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const Icon(Icons.stars, color: Colors.white, size: 48),
                  const SizedBox(height: 8),
                  Text('$points', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                  const Text('Points Earned', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('${totalKg.toStringAsFixed(1)} kg recycled total',
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 20),
              // How to earn
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('How to Earn Points', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green[800])),
                    const SizedBox(height: 12),
                    _earnRow(Icons.recycling,          '+50 pts', 'Submit a pickup request'),
                    _earnRow(Icons.volunteer_activism, '+30 pts', 'Donate e-waste'),
                    _earnRow(Icons.rate_review,        '+10 pts', 'Write a review'),
                    _earnRow(Icons.emoji_events,       'Bonus',   'Reach Bronze/Silver/Gold milestones'),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              // Recent activity
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Recent Pickups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green[800])),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('pickup_requests')
                          .where('userId', isEqualTo: user.uid)
                          .orderBy('timestamp', descending: true)
                          .limit(5)
                          .snapshots(),
                      builder: (context, reqSnap) {
                        if (!reqSnap.hasData) return const Center(child: CircularProgressIndicator());
                        final docs = reqSnap.data!.docs;
                        if (docs.isEmpty) return Text('No pickups yet', style: TextStyle(color: Colors.grey[500]));
                        return Column(children: docs.map((d) {
                          final rd = d.data() as Map<String, dynamic>;
                          final status = rd['status'] ?? 'Pending';
                          final reward = (rd['totalReward'] as num? ?? 0).toInt();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.recycling,
                                color: status == 'Completed' ? Colors.green : Colors.grey),
                            title: Text('₹$reward estimated reward'),
                            subtitle: Text(status),
                            trailing: status == 'Completed'
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                          );
                        }).toList());
                      },
                    ),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _earnRow(IconData icon, String pts, String desc) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, color: Colors.green[700], size: 20),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
        child: Text(pts, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[700])),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(desc, style: const TextStyle(fontSize: 13))),
    ]),
  );
}
