// lib/services/pickup_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PickupService {
  final _db = FirebaseFirestore.instance;

  /// Creates a pickup request document.
  /// Returns null on success, or an error string on failure.
  Future<String?> createPickupRequest(Map<String, dynamic> data) async {
    try {
      await _db.collection('pickup_requests').add(data);
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  /// Stream of pickup requests for a given user UID.
  Stream<QuerySnapshot> userRequestsStream(String uid) {
    return _db
        .collection('pickup_requests')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Single fetch of all pickup requests (admin use).
  Future<List<Map<String, dynamic>>> allRequests() async {
    final snap = await _db
        .collection('pickup_requests')
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Update request status.
  Future<String?> updateStatus(String id, String status) async {
    try {
      await _db.collection('pickup_requests').doc(id).update({'status': status});
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
