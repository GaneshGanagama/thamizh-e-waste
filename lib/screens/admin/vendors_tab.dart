// lib/screens/admin/vendors_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorsTab extends StatefulWidget {
  const VendorsTab({super.key});

  @override
  State<VendorsTab> createState() => _VendorsTabState();
}

class _VendorsTabState extends State<VendorsTab> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text("Vendor Management"),
          backgroundColor: Colors.green[700],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "Requests"),
              Tab(text: "Approved"),
              Tab(text: "Rejected"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _VendorList(status: 'pending'),
            _VendorList(status: 'approved'),
            _VendorList(status: 'rejected'),
          ],
        ),
      ),
    );
  }
}

class _VendorList extends StatelessWidget {
  final String status;
  const _VendorList({required this.status});

  Color _statusColor() {
    switch (status) {
      case 'approved':
        return Colors.green[50]!;
      case 'rejected':
        return Colors.red[50]!;
      default:
        return Colors.orange[50]!;
    }
  }

  IconData _statusIcon() {
    switch (status) {
      case 'approved':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending_actions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = status == 'pending';

    final Query query = status == 'approved'
        ? FirebaseFirestore.instance
            .collection('vendors')
            .orderBy('approvedAt', descending: true)
        : FirebaseFirestore.instance
            .collection('vendor_requests')
            .where('status', isEqualTo: status)
            .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          if (error.contains("requires an index")) {
            return _buildIndexError(error);
          }
          return Center(
            child: Text(
              "Error loading $status vendors:\n${snapshot.error}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              "No ${status == 'pending' ? 'pending requests' : '$status vendors'}",
              style: const TextStyle(color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                tileColor: _statusColor(),
                leading: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(
                    _statusIcon(),
                    color: status == 'approved'
                        ? Colors.green
                        : status == 'rejected'
                            ? Colors.red
                            : Colors.orange,
                  ),
                ),
                title: Text(
                  data['shopName'] ?? 'Shop Name',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  "${data['ownerName'] ?? ''}\n📞 ${data['contact'] ?? ''}",
                  style: const TextStyle(height: 1.3),
                ),
                isThreeLine: true,
                onTap: () => _showVendorDetails(context, data),
                trailing: isPending
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: "Approve Vendor",
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Approve vendor'),
                                      content:
                                          const Text('Approve this vendor?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(c).pop(false),
                                            child: const Text('Cancel')),
                                        ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(c).pop(true),
                                            child: const Text('Approve')),
                                      ],
                                    ),
                                  ) ??
                                  false;

                              if (ok)
                                await _VendorActions.approve(doc, context);
                            },
                          ),
                          IconButton(
                            tooltip: "Reject Vendor",
                            icon: const Icon(Icons.cancel,
                                color: Colors.redAccent),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Reject vendor'),
                                      content:
                                          const Text('Reject this vendor?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(c).pop(false),
                                            child: const Text('Cancel')),
                                        ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(c).pop(true),
                                            child: const Text('Reject')),
                                      ],
                                    ),
                                  ) ??
                                  false;

                              if (ok) await _VendorActions.reject(doc, context);
                            },
                          ),
                        ],
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  /// 🔹 Firestore index-error message UI
  Widget _buildIndexError(String error) {
    final linkMatch =
        RegExp(r'https:\/\/console\.firebase\.google\.com\/[^\s]+')
            .firstMatch(error);
    final link = linkMatch?.group(0);

    Future<void> openIndexLink(String url) async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // fallback: open plain url
        await launchUrl(Uri.parse(url));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 50, color: Colors.orange),
            const SizedBox(height: 12),
            const Text(
              "⚠️ Firestore Index Required",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.redAccent),
            ),
            const SizedBox(height: 10),
            const Text(
              "Firestore needs an index for this query.\n"
              "Click below to create it automatically:",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (link != null)
              InkWell(
                onTap: () => openIndexLink(link),
                child: Text(
                  "➡ Create Firestore Index",
                  style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================
/// Bottom sheet: details + static map preview
/// =========================
void _showVendorDetails(BuildContext context, Map<String, dynamic> data) {
  // Helper to safely convert to double
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v);
    }
    return null;
  }

  final double? lat = _toDouble(data['latitude']);
  final double? lng = _toDouble(data['longitude']);

  // Use OpenStreetMap static map (free, no API key)
  final String? staticMapUrl = (lat != null && lng != null)
      ? 'https://staticmap.openstreetmap.de/staticmap.php?center=$lat,$lng&zoom=17&size=600x300&markers=$lat,$lng,red-pushpin'
      : null;

  Future<void> openGoogleMaps() async {
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location not available")));
      return;
    }
    final Uri url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // fallback
      await launchUrl(url);
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: 18 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['shopName'] ?? "Shop Name",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("👤 Owner: ${data['ownerName'] ?? 'N/A'}"),
              Text("📞 Contact: ${data['contact'] ?? 'N/A'}"),
              if ((data['address'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text("📍 Address: ${data['address']}"),
                ),
              const SizedBox(height: 12),
              if (staticMapUrl != null) ...[
                const Text("🗺 Location Preview",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    staticMapUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (c, e, s) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                            child: Text("Unable to load map preview")),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text("Latitude: $lat"),
                Text("Longitude: $lng"),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: openGoogleMaps,
                  icon: const Icon(Icons.map),
                  label: const Text("Open in Google Maps"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text("Location not provided"),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text("Close"),
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800]),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// =========================
/// Vendor approve / reject actions
/// =========================
class _VendorActions {
  static Future<void> approve(
      DocumentSnapshot doc, BuildContext context) async {
    final data = doc.data() as Map<String, dynamic>;
    final String? userId = (data['userId'] ?? data['uid'])?.toString();
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing userId")),
      );
      return;
    }

    try {
      // update users collection role
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'role': 'vendor',
      }, SetOptions(merge: true));

      // copy to vendors collection
      await FirebaseFirestore.instance.collection('vendors').doc(userId).set({
        'userId': userId,
        'shopName': data['shopName'] ?? '',
        'ownerName': data['ownerName'] ?? '',
        'contact': data['contact'] ?? data['phone'] ?? '',
        'address': data['address'] ?? '',
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // add history
      await FirebaseFirestore.instance.collection('vendor_history').add({
        'userId': userId,
        'action': 'approved',
        'details': data,
        'changedByUid': FirebaseAuth.instance.currentUser?.uid,
        'changedByEmail': FirebaseAuth.instance.currentUser?.email,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // delete original request
      await doc.reference.delete();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Vendor approved ✅")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Approval failed: $e")));
    }
  }

  static Future<void> reject(DocumentSnapshot doc, BuildContext context) async {
    final data = doc.data() as Map<String, dynamic>;
    final String? userId = (data['userId'] ?? data['uid'])?.toString();

    try {
      await FirebaseFirestore.instance
          .collection('vendor_requests')
          .doc(doc.id)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // add history
      await FirebaseFirestore.instance.collection('vendor_history').add({
        'userId': userId,
        'action': 'rejected',
        'details': data,
        'changedByUid': FirebaseAuth.instance.currentUser?.uid,
        'changedByEmail': FirebaseAuth.instance.currentUser?.email,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Vendor rejected ❌")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Rejection failed: $e")));
    }
  }
}
