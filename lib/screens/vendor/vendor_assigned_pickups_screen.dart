import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class VendorAssignedPickupsScreen extends StatelessWidget {
  const VendorAssignedPickupsScreen({super.key});

  void _showPickupDetails(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Extract address string
    String address = 'No address';
    final addrField = data['address'];
    if (addrField is Map) {
      address = (addrField['readable'] ?? '').toString().trim();
      if (address.isEmpty) {
        final parts = [
          addrField['house'],
          addrField['area'],
          addrField['village'],
          addrField['district'],
        ].where((s) => (s ?? '').toString().isNotEmpty).toList();
        address = parts.join(', ');
      }
    } else if (addrField is String && addrField.isNotEmpty) {
      address = addrField;
    }

    final phone = (data['contactPhone'] ?? data['userPhone'] ?? '').toString();
    final items = (data['items'] as List<dynamic>? ?? []);
    final status = (data['status'] ?? 'Pending').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Pickup Details',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _detailRow(
                  Icons.person, 'User: ${data['userName'] ?? 'Unknown'}'),
              const SizedBox(height: 8),
              _detailRow(Icons.location_on, 'Address: $address'),
              const SizedBox(height: 8),
              _detailRow(Icons.phone,
                  'Phone: ${phone.isNotEmpty ? phone : 'Not provided'}'),
              const SizedBox(height: 8),
              _detailRow(Icons.info_outline, 'Status: $status'),
              const SizedBox(height: 12),

              // Items list
              if (items.isNotEmpty) ...[
                const Text('Items:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                ...items.map((item) {
                  final it = item as Map<dynamic, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          '${it['wasteType'] ?? 'Item'}'
                          '${it['weight'] != null ? ' — ${it['weight']} kg' : ''}'
                          '${it['reward'] != null ? '  ₹${it['reward']}' : ''}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],

              // Action buttons
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Collected'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700]),
                    onPressed: status == 'Completed'
                        ? null
                        : () {
                            Navigator.pop(context);
                            // Vendors mark items "Collected", not "Completed".
                            // Only the admin's Complete action credits impact
                            // stats and reward points — if vendors could set
                            // "Completed" directly, that logic never runs.
                            FirebaseFirestore.instance
                                .collection('pickup_requests')
                                .doc(doc.id)
                                .update({'status': 'Collected'});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Marked as collected — pending admin confirmation')),
                            );
                          },
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.call, color: Colors.green),
                    label: const Text('Call',
                        style: TextStyle(color: Colors.green)),
                    onPressed: () async {
                      final uri = Uri.parse('tel:$phone');
                      if (await canLaunchUrl(uri)) {
                        launchUrl(uri);
                      }
                    },
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.green[700]),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null) {
      return const Scaffold(
          body: Center(child: Text('Please log in to view pickups')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Assigned Pickups"),
        backgroundColor: Colors.green[700],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pickup_requests')
            .where('assignedTo', isEqualTo: vendorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "No pickups assigned to you yet.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final status = (data['status'] ?? 'Pending').toString();
              final statusColor = _statusColor(status);

              // Address display
              String address = 'No address';
              final addrField = data['address'];
              if (addrField is Map) {
                final r = (addrField['readable'] ?? '').toString().trim();
                address = r.isNotEmpty ? r : 'Tap for details';
              } else if (addrField is String && addrField.isNotEmpty) {
                address = addrField;
              }

              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _showPickupDetails(context, doc),
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Icon(Icons.local_shipping, color: statusColor),
                  ),
                  title: Text(
                    data['userName'] ?? 'Unknown User',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Tap for details',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
