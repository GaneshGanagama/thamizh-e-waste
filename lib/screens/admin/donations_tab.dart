import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class DonationsTab extends StatelessWidget {
  const DonationsTab({super.key});

  Future<void> _updateDonationStatus(
    String id,
    String status,
    BuildContext context,
  ) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('donations').doc(id);
      final snap = await docRef.get();
      final oldStatus = (snap.data()?['status'] ?? 'Pending').toString();

      if (oldStatus == status) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status unchanged')),
        );
        return;
      }

      // Same lock as pickup requests: once Collected, impact has already
      // been credited, so reverting and re-collecting would double-count.
      if (oldStatus == 'Collected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'This donation is already Collected and locked. Status can\'t be changed.')),
        );
        return;
      }

      await docRef.update({'status': status});

      // ── Impact update when marking Collected ─────────────────────────────
      if (status == 'Collected') {
        try {
          final donationData = snap.data() ?? {};

          if (donationData['impactApplied'] == true) {
            debugPrint('⚠️ Impact already applied for donation $id, skipping.');
            return;
          }

          // Missing weight should NOT be assumed as 1kg — that silently
          // inflates impact numbers for every donation without a recorded
          // weight. 0 is the honest default; fix the weight at intake instead.
          final double donationKg =
              (donationData['weight'] as num? ?? 0).toDouble();

          final factorsSnap = await FirebaseFirestore.instance
              .collection('settings').doc('impact_factors').get();
          final f = factorsSnap.data() ?? {};
          final treeFactor  = (f['tree']  ?? 30.0).toDouble();
          final waterFactor = (f['water'] ?? 5.0).toDouble();
          final co2Factor   = (f['co2']   ?? 1.6).toDouble();

          final impactBatch = FirebaseFirestore.instance.batch();
          final impactRef = FirebaseFirestore.instance
              .collection('settings').doc('total_impact');
          impactBatch.set(impactRef, {
            'totalKg':     FieldValue.increment(donationKg),
            'treesSaved':  FieldValue.increment(
                treeFactor > 0 ? donationKg / treeFactor : 0),
            'waterLitres': FieldValue.increment(donationKg * waterFactor),
            'co2Kg':       FieldValue.increment(donationKg * co2Factor),
          }, SetOptions(merge: true));

          final userId = (donationData['userId'] ?? '').toString();
          if (userId.isNotEmpty) {
            final userRef = FirebaseFirestore.instance
                .collection('users').doc(userId);
            impactBatch.update(userRef, {
              'totalRecycledWeight': FieldValue.increment(donationKg),
            });
          }
          impactBatch.update(docRef, {'impactApplied': true});
          await impactBatch.commit();
        } catch (e) {
          debugPrint('⚠️ Donation impact update failed: $e');
        }
      }
      // ─────────────────────────────────────────────────────────────────────

      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('donation_history').add({
        'donationId': id,
        'oldStatus': oldStatus,
        'newStatus': status,
        'changedByUid': user?.uid,
        'changedByEmail': user?.email,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Donation updated to $status')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _confirmAndUpdate(
    String id,
    String newStatus,
    BuildContext context,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Confirm status change'),
            content: Text('Change donation status to "$newStatus"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.of(c).pop(true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await _updateDonationStatus(id, newStatus, context);
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final Uri url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'collected':
        color = Colors.green;
        break;
      case 'cancelled':
      case 'rejected':
        color = Colors.red;
        break;
      case 'pending':
      default:
        color = Colors.orange;
    }

    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(status,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No donations yet'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>? ?? {};

            final name =
                (data['userName'] ?? data['name'] ?? 'Unknown').toString();
            final contact = (data['contactPhone'] ??
                    data['userPhone'] ??
                    data['phone'] ??
                    'No phone')
                .toString();
            String address = 'No address';
            final addr = data['address'];
            double? lat, lng;
            if (addr is Map) {
              if ((addr['readable'] ?? '').toString().trim().isNotEmpty) {
                address = addr['readable'];
              } else {
                final h = addr['house'] ?? '';
                final a = addr['area'] ?? '';
                final v = addr['village'] ?? '';
                final d = addr['district'] ?? '';
                address = [h, a, v, d]
                    .where((s) => (s ?? '').toString().isNotEmpty)
                    .join(', ');
              }
              if (addr['latitude'] != null && addr['longitude'] != null) {
                try {
                  lat = double.parse(addr['latitude'].toString());
                  lng = double.parse(addr['longitude'].toString());
                } catch (_) {}
              }
            }

            final imageUrl = (data['imageUrl'] ?? '').toString();
            final status = (data['status'] ?? 'Pending').toString();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name),
                    _statusChip(status),
                  ],
                ),
                subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📞 $contact'),
                      const SizedBox(height: 4),
                      Text('📍 ${address.isNotEmpty ? address : 'No address'}'),
                    ]),
                children: [
                  if (imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.network(imageUrl,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported)),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    child: Row(children: [
                      ElevatedButton(
                        onPressed: status == 'Collected'
                            ? null
                            : () => _confirmAndUpdate(
                                doc.id, 'Collected', context),
                        child: const Text('Mark Collected'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                        onPressed: status == 'Collected'
                            ? null
                            : () => _confirmAndUpdate(
                                doc.id, 'Cancelled', context),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      if (lat != null && lng != null)
                        IconButton(
                          icon: const Icon(Icons.map, color: Colors.blue),
                          onPressed: () => _openInMaps(lat!, lng!),
                        ),
                    ]),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
