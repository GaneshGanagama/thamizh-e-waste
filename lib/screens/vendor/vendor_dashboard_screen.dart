// lib/screens/vendor/vendor_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../routes/app_routes.dart';

class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendors').where('userId', isEqualTo: user.uid).limit(1).snapshots(),
        builder: (context, snap) {
          final vendorData = snap.data?.docs.isNotEmpty == true
              ? snap.data!.docs.first.data() as Map<String, dynamic> : {};
          final shopName = vendorData['shopName'] ?? 'Vendor';
          final status   = vendorData['status']   ?? 'pending';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.blue[700]!, Colors.blue[400]!]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const Icon(Icons.store, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(shopName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'approved' ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              if (status != 'approved') ...[
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.hourglass_empty, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(child: Text(
                        'Your vendor application is under review. You will be notified once approved.',
                        style: TextStyle(color: Colors.grey[700]),
                      )),
                    ]),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
                _navCard(context, Icons.local_shipping, 'Assigned Pickups',
                    'View and manage pickup requests', AppRoutes.vendorPickups, Colors.green),
                const SizedBox(height: 12),
                _navCard(context, Icons.move_to_inbox, 'Drop-off Requests',
                    'Manage drop-off submissions', AppRoutes.vendorDropoff, Colors.teal),
                const SizedBox(height: 12),
                _navCard(context, Icons.person, 'My Profile',
                    'View and update your profile', AppRoutes.vendorProfile, Colors.purple),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _navCard(BuildContext ctx, IconData icon, String title, String sub, String route, Color color) =>
      GestureDetector(
        onTap: () => Navigator.pushNamed(ctx, route),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
          ),
        ),
      );
}
