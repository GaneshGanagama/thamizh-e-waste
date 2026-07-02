import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class RequestsTab extends StatelessWidget {
  const RequestsTab({super.key});

  // ---------------- ACTIONS ----------------

  Future<void> _updateRequestStatus(
    String id,
    String status,
    BuildContext context,
  ) async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('pickup_requests').doc(id);

      // Read current status so we can record history
      final snap = await docRef.get();
      final oldStatus = (snap.data()?['status'] ?? 'Pending').toString();

      if (oldStatus == status) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Status unchanged")),
        );
        return;
      }

      await docRef.update({"status": status});

      // ── Impact update when marking Completed ─────────────────────────────
      if (status == "Completed") {
        try {
          final pickupData = snap.data() ?? {};
          final items = (pickupData['items'] as List<dynamic>? ?? []);
          double totalKg = 0;
          for (final it in items) {
            totalKg += (it['weight'] as num? ?? 0).toDouble();
          }

          // Read impact factors
          final factorsSnap = await FirebaseFirestore.instance
              .collection('settings')
              .doc('impact_factors')
              .get();
          final f = factorsSnap.data() ?? {};
          final treeFactor  = (f['tree']  ?? 30.0).toDouble();
          final waterFactor = (f['water'] ?? 5.0).toDouble();
          final co2Factor   = (f['co2']   ?? 1.6).toDouble();

          final batch = FirebaseFirestore.instance.batch();

          // Increment total_impact
          final impactRef = FirebaseFirestore.instance
              .collection('settings').doc('total_impact');
          batch.set(impactRef, {
            'totalKg':    FieldValue.increment(totalKg),
            'treesSaved': FieldValue.increment(
                treeFactor > 0 ? totalKg / treeFactor : 0),
            'waterLitres': FieldValue.increment(totalKg * waterFactor),
            'co2Kg':       FieldValue.increment(totalKg * co2Factor),
          }, SetOptions(merge: true));

          // Increment user totalRecycledWeight
          final userId = (pickupData['userId'] ?? '').toString();
          if (userId.isNotEmpty) {
            final userRef = FirebaseFirestore.instance
                .collection('users').doc(userId);
            batch.update(userRef, {
              'totalRecycledWeight': FieldValue.increment(totalKg),
            });
          }

          await batch.commit();
        } catch (impactErr) {
          debugPrint('⚠️ Impact update failed: $impactErr');
        }
      }
      // ─────────────────────────────────────────────────────────────────────

      // Write an audit entry
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('request_history').add({
        'requestId': id,
        'oldStatus': oldStatus,
        'newStatus': status,
        'changedByUid': user?.uid,
        'changedByEmail': user?.email,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request updated to $status")),
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
            content: Text('Change request status to "$newStatus"?'),
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

  // ---------------- WIDGET HELPERS ----------------

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case "Completed":
        color = Colors.green;
        break;
      case "In Progress":
        color = Colors.orange;
        break;
      case "Cancelled":
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      backgroundColor: color.withOpacity(0.2),
      label: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ---------------- MAIN UI ----------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pickup_requests')
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
          return const Center(child: Text("No pickup requests"));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>? ?? {};

            // -------- BASIC FIELDS --------
            final userName =
                (data["userName"] ?? data["name"] ?? "Unknown").toString();
            final email =
                (data["userEmail"] ?? data["email"] ?? "No email").toString();
            // Prefer 'contactPhone' (newer field), then legacy variants
            final phoneRaw = (data["contactPhone"] ??
                    data["contact_phone"] ??
                    data["userPhone"] ??
                    data["user_phone"] ??
                    data["phone"] ??
                    "")
                .toString();
            final phone = phoneRaw.isNotEmpty ? phoneRaw : "No phone";
            final reward = data["totalReward"]?.toString() ?? "0";
            final imageUrl = (data["imageUrl"] ?? "").toString();
            final status = (data["status"] ?? "Pending").toString();

            // -------- LOCATION HANDLING --------
            final locField = data["location"];
            String address = "No address";
            GeoPoint? geo;
            String? mapLink;

            if (locField is Map) {
              // readable text (preferred)
              if (locField["readable"] != null &&
                  locField["readable"].toString().trim().isNotEmpty) {
                address = locField["readable"];
              }

              // mapLink support
              if (locField["mapLink"] != null) {
                mapLink = locField["mapLink"].toString();
              }

              // coordinates
              if (locField["latitude"] != null &&
                  locField["longitude"] != null) {
                try {
                  final lat = locField["latitude"] is num
                      ? locField["latitude"].toDouble()
                      : double.parse(locField["latitude"].toString());
                  final lng = locField["longitude"] is num
                      ? locField["longitude"].toDouble()
                      : double.parse(locField["longitude"].toString());

                  geo = GeoPoint(lat, lng);

                  if (address == "No address") {
                    address = "Lat: $lat, Lng: $lng";
                  }
                } catch (_) {}
              }
            } else if (locField is GeoPoint) {
              geo = locField;
              address = "Lat: ${geo.latitude}, Lng: ${geo.longitude}";
            } else if (data["address"] != null) {
              address = data["address"].toString();
            }

            // -------- ITEMS --------
            final items = (data["items"] as List<dynamic>? ?? [])
                .map((it) => Map<String, dynamic>.from(it))
                .toList();

            // -------- UI CARD --------

            return Card(
              margin: const EdgeInsets.all(8),
              child: ExpansionTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$userName • ₹$reward"),
                    _buildStatusChip(status),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("📧 $email"),
                    Text("📞 $phone"),
                    const SizedBox(height: 6),

                    // ---- address OR coordinates ----
                    if (address != "No address" && geo == null)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _openAddressInMaps(address),
                              onLongPress: () {
                                Clipboard.setData(ClipboardData(text: address));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Address copied")),
                                );
                              },
                              child: Text(
                                "📍 $address",
                                style: const TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          if (mapLink != null)
                            IconButton(
                              icon: const Icon(Icons.map, color: Colors.blue),
                              onPressed: () => _openAddressInMaps(mapLink!),
                            )
                        ],
                      )
                    else if (geo != null)
                      InkWell(
                        onTap: () => _openInMaps(geo!.latitude, geo.longitude),
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(
                              text: "${geo!.latitude},${geo.longitude}"));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Coordinates copied")),
                          );
                        },
                        child: Text(
                          "📍 Lat: ${geo.latitude}, Lng: ${geo.longitude}",
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    else
                      const Text("📍 No location available"),
                  ],
                ),
                children: [
                  // -------- IMAGE --------
                  if (imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Image.network(
                        imageUrl,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.image_not_supported,
                          size: 80, color: Colors.grey),
                    ),

                  const Divider(),

                  // -------- ITEM LIST --------
                  const Text("Items:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if (items.isEmpty) const Text("No items provided"),
                  if (items.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: items
                          .map(
                            (m) => Chip(
                              label: Text(
                                  "${m['wasteType'] ?? 'Unknown'} ${m['weight'] ?? ''}kg • ₹${m['reward'] ?? 0}"),
                            ),
                          )
                          .toList(),
                    ),

                  const SizedBox(height: 8),

                  // -------- Admin Action Buttons --------
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
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () =>
                            _confirmAndUpdate(doc.id, "Cancelled", context),
                        child: const Text("Cancel"),
                      ),
                      const Spacer(),
                      if (phoneRaw.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => _callPhone(phoneRaw),
                        ),
                      if (geo != null)
                        IconButton(
                          icon: const Icon(Icons.map, color: Colors.blue),
                          onPressed: () =>
                              _openInMaps(geo!.latitude, geo.longitude),
                        ),
                    ],
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
