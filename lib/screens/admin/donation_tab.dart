import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class DonationTab extends StatelessWidget {
  const DonationTab({super.key});

  // ---------------- ACTIONS ----------------

  Future<void> _updateRequestStatus(
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
          const SnackBar(content: Text("Status unchanged")),
        );
        return;
      }

      await docRef.update({"status": status});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Donation marked as $status")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
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
      await _updateRequestStatus(id, newStatus, context);
    }
  }

  Future<void> _callPhone(String phone) async {
    final Uri url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final Uri url =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openAddressInMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    final Uri url =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$encoded");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ---------------- MAIN UI ----------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text("Error: ${snap.error}"));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No donations received"));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>? ?? {};

            final userName = (data["userName"] ?? "Unknown").toString();
            final email = (data["userEmail"] ?? "No email").toString();
            final phone = (data["contactPhone"] ?? "No phone").toString();
            final imageUrl = (data["imageUrl"] ?? "").toString();
            final status = (data["status"] ?? "Pending").toString();

            // ADDRESS
            String address = "No address";
            if (data["address"] is Map) {
              final a = data["address"];
              address =
                  "${a["house"] ?? ''}, ${a["area"] ?? ''}, ${a["village"] ?? ''}, ${a["district"] ?? ''}";
            }

            // LOCATION
            double? lat, lng;
            if (data["location"] is Map) {
              lat = (data["location"]["latitude"])?.toDouble();
              lng = (data["location"]["longitude"])?.toDouble();
            }

            return Card(
              margin: const EdgeInsets.all(8),
              child: ExpansionTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(userName),
                    Chip(
                      label: Text(status),
                      backgroundColor: status == "Completed"
                          ? Colors.green.shade200
                          : status == "In Progress"
                              ? Colors.orange.shade200
                              : Colors.grey.shade300,
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("📧 $email"),
                    Text("📞 $phone"),
                    InkWell(
                      onTap: () => _openAddressInMaps(address),
                      child: Text(
                        "📍 $address",
                        style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                    if (lat != null && lng != null)
                      InkWell(
                        onTap: () => _openInMaps(lat!, lng!),
                        child: Text(
                          "🌐 $lat, $lng",
                          style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline),
                        ),
                      ),
                  ],
                ),
                children: [
                  if (imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.network(
                        imageUrl,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const Divider(),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            _confirmAndUpdate(doc.id, "Completed", context),
                        child: const Text("Complete"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _confirmAndUpdate(doc.id, "In Progress", context),
                        child: const Text("In Progress"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _confirmAndUpdate(doc.id, "Cancelled", context),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text("Cancel"),
                      ),
                      const Spacer(),
                      if (phone != "No phone")
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => _callPhone(phone),
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
  }
}
