import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _vendorStream;
  String? _uid;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;

    if (user != null) {
      _vendorStream = FirebaseFirestore.instance
          .collection('vendors')
          .doc(user.uid)
          .snapshots();
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() => _loggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _loggingOut = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not sign out. Please try again.'),
        ),
      );
    }
  }

  void _retryLoading() {
    final uid = _uid;
    if (uid == null) return;

    setState(() {
      _vendorStream =
          FirebaseFirestore.instance.collection('vendors').doc(uid).snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vendor Dashboard')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please log in to continue.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  );
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _vendorStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message(
              icon: Icons.cloud_off,
              title: 'Could not load vendor details',
              message:
                  'Check your connection or access permissions and try again.',
              actionLabel: 'Retry',
              onAction: _retryLoading,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _message(
              icon: Icons.store_outlined,
              title: 'Vendor record not found',
              message:
                  'No vendor record was found for this account. Please contact the administrator.',
              actionLabel: 'Retry',
              onAction: _retryLoading,
            );
          }

          final vendorData = snapshot.data!.data()!;
          final linkedUid = vendorData['userId']?.toString();

          if (linkedUid != null && linkedUid != _uid) {
            return _message(
              icon: Icons.lock_outline,
              title: 'Access denied',
              message: 'This vendor record does not match your account.',
            );
          }

          final shopName =
              vendorData['shopName']?.toString().trim().isNotEmpty == true
                  ? vendorData['shopName'].toString()
                  : 'Vendor';

          final status = (vendorData['status'] ?? 'unknown')
              .toString()
              .trim()
              .toLowerCase();

          final approved = status == 'approved';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue[700]!,
                        Colors.blue[400]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.store,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        shopName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (approved) ...[
                  _navCard(
                    Icons.local_shipping,
                    'Assigned Pickups',
                    'View and manage pickup requests',
                    AppRoutes.vendorPickups,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _navCard(
                    Icons.move_to_inbox,
                    'Drop-off Requests',
                    'Manage drop-off submissions',
                    AppRoutes.vendorDropoff,
                    Colors.teal,
                  ),
                  const SizedBox(height: 12),
                  _navCard(
                    Icons.person,
                    'My Profile',
                    'View and update your profile',
                    AppRoutes.vendorProfile,
                    Colors.purple,
                  ),
                ] else
                  _statusMessage(status),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _statusMessage(String status) {
    late final String message;
    late final IconData icon;
    late final Color color;

    switch (status) {
      case 'pending':
        message =
            'Your vendor application is under review. Please wait for the administrator.';
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        break;
      case 'rejected':
        message =
            'Your vendor application was rejected. Please contact the administrator.';
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      default:
        message =
            'Your vendor status could not be confirmed. Please contact the administrator.';
        icon = Icons.info_outline;
        color = Colors.blueGrey;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _navCard(
    IconData icon,
    String title,
    String subtitle,
    String route,
    Color color,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}
