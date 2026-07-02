// lib/services/notification_service.dart
// Sends FCM push notifications to admin when a new pickup/donation is submitted.
//
// SETUP (one-time):
//   1. Enable Cloud Messaging in Firebase Console
//   2. Add google-services.json (Android) / GoogleService-Info.plist (iOS)
//   3. Add firebase_messaging to pubspec.yaml
//   4. In Firebase Console → Cloud Messaging → Create a topic called "admin_alerts"
//   5. In your admin app startup (admindashboard_screen initState), call:
//        NotificationService.subscribeAdminToAlerts();
//
// HOW IT WORKS:
//   When user submits pickup → calls NotificationService.notifyAdminNewPickup()
//   → writes a doc to 'admin_notifications' collection in Firestore
//   → a Cloud Function (or the admin panel) reads and shows these in-app
//   → FCM is triggered via Firebase Cloud Functions (see note below)
//
// IN-APP NOTIFICATIONS (no Cloud Functions needed):
//   The admin panel reads 'admin_notifications' in real-time via Firestore.
//   This works without any server-side code.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  /// Call this when user submits a pickup request.
  /// Writes a notification document that the admin panel reads in real-time.
  static Future<void> notifyAdminNewPickup({
    required String requestId,
    required String userName,
    required String address,
    required double totalReward,
  }) async {
    try {
      await _db.collection('admin_notifications').add({
        'type': 'new_pickup',
        'title': '🚛 New Pickup Request',
        'body': '$userName submitted a pickup — ₹${totalReward.toStringAsFixed(0)}',
        'requestId': requestId,
        'userName': userName,
        'address': address,
        'totalReward': totalReward,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-critical — don't block the user flow
    }
  }

  /// Call this when user submits a donation.
  static Future<void> notifyAdminNewDonation({
    required String donationId,
    required String userName,
    required String address,
  }) async {
    try {
      await _db.collection('admin_notifications').add({
        'type': 'new_donation',
        'title': '🎁 New Donation',
        'body': '$userName wants to donate e-waste',
        'donationId': donationId,
        'userName': userName,
        'address': address,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-critical
    }
  }

  /// Mark a notification as read.
  static Future<void> markRead(String notificationId) async {
    try {
      await _db
          .collection('admin_notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (_) {}
  }

  /// Mark ALL notifications as read.
  static Future<void> markAllRead() async {
    try {
      final snap = await _db
          .collection('admin_notifications')
          .where('read', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Stream of unread notification count (for badge on admin sidebar).
  static Stream<int> unreadCountStream() {
    return _db
        .collection('admin_notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Stream of all notifications (newest first).
  static Stream<QuerySnapshot> notificationsStream() {
    return _db
        .collection('admin_notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }
}
