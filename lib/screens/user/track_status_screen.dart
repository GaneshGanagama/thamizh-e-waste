// lib/screens/user/track_status_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TrackStatusScreen extends StatelessWidget {
  const TrackStatusScreen({super.key});

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'in progress': return Colors.blue;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return Icons.check_circle;
      case 'in progress': return Icons.local_shipping;
      case 'cancelled': return Icons.cancel;
      default: return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Track My Requests'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Pickups',  icon: Icon(Icons.recycling, size: 18)),
              Tab(text: 'Donations', icon: Icon(Icons.volunteer_activism, size: 18)),
            ],
          ),
        ),
        body: TabBarView(children: [
          _buildList(user.uid, 'pickup_requests'),
          _buildList(user.uid, 'donations'),
        ]),
      ),
    );
  }

  Widget _buildList(String uid, String collection) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No ${collection == 'pickup_requests' ? 'pickups' : 'donations'} yet',
                style: TextStyle(color: Colors.grey[500])),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final status  = (data['status'] ?? 'Pending').toString();
            final reward  = (data['totalReward'] as num? ?? 0).toInt();
            final ts      = data['timestamp'];
            String date   = '';
            if (ts is Timestamp) {
              date = DateFormat('dd MMM yyyy').format(ts.toDate());
            }
            final addr = data['address'];
            String addrStr = '';
            if (addr is Map) {
              addrStr = addr['readable'] ?? '${addr['area'] ?? ''}, ${addr['city'] ?? ''}';
            } else if (addr is String) {
              addrStr = addr;
            }
            final items = (data['items'] as List<dynamic>? ?? []);
            final scheduled = data['scheduledAt'];
            final priority  = data['priority'] ?? 'Normal';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(_statusIcon(status), color: _statusColor(status), size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(status, style: TextStyle(
                        fontWeight: FontWeight.bold, color: _statusColor(status)))),
                    if (priority == 'Urgent')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Urgent', style: TextStyle(
                            fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.bold)),
                      ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ]),
                  if (addrStr.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.location_on, size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Expanded(child: Text(addrStr,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                    ]),
                  ],
                  if (scheduled != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today, size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('Scheduled: $scheduled',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ]),
                  ],
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 4,
                      children: items.map((it) => Chip(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text('${it['wasteType']} ${it['weight']}kg',
                            style: const TextStyle(fontSize: 11)),
                      )).toList(),
                    ),
                  ],
                  if (reward > 0) ...[
                    const SizedBox(height: 8),
                    Text('Estimated reward: ₹$reward',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green[700])),
                  ],
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
