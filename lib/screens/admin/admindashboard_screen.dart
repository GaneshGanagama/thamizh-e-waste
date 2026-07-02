// lib/screens/admin/admindashboard_screen.dart
//
// CHANGES:
// • Removed duplicate DonationsTab (kept DonationTab only)
// • Added Audit Log tab (reads request_history + donation_history)
// • Removed unused import of donations_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'requests_tab.dart';
import 'donations_tab.dart';
import 'scrap_prices_tab.dart';
import 'banners_tab.dart';
import 'announcements_tab.dart';
import 'awareness_tab.dart';
import 'vendors_tab.dart';
import 'vendor_history_tab.dart';
import 'certificates_tab.dart';
import 'drop_points_tab.dart';
import 'impact_settings_tab.dart';
import '../../services/notification_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _loadingSummary = true;
  String _adminEmail = '';

  Map<String, dynamic> _summary = {
    'users': 0,
    'pickups': 0,
    'donations': 0,
    'vendors': 0,
  };

  // ── ALL ADMIN TABS ────────────────────────────────────────────────────────

  late final List<Map<String, dynamic>> _tabs = [
    {
      'icon': Icons.list_alt,
      'label': 'Requests',
      'widget': const RequestsTab()
    },
    {
      'icon': Icons.volunteer_activism,
      'label': 'Donations',
      'widget': const DonationsTab()
    },
    {
      'icon': Icons.price_check,
      'label': 'Scrap Prices',
      'widget': const ScrapPricesTab()
    },
    {'icon': Icons.image, 'label': 'Banners', 'widget': const BannersTab()},
    {
      'icon': Icons.campaign,
      'label': 'Announcements',
      'widget': const AnnouncementsTab()
    },
    {
      'icon': Icons.lightbulb,
      'label': 'Awareness',
      'widget': const AwarenessTab()
    },
    {'icon': Icons.store, 'label': 'Vendors', 'widget': const VendorsTab()},
    {
      'icon': Icons.history,
      'label': 'Vendor History',
      'widget': const VendorHistoryTab()
    },
    {
      'icon': Icons.picture_as_pdf,
      'label': 'Certificates',
      'widget': const CertificatesTab()
    },
    {
      'icon': Icons.location_on,
      'label': 'Drop Points',
      'widget': const DropPointsTab()
    },
    {'icon': Icons.eco, 'label': 'Impact', 'widget': const ImpactSettingsTab()},
    {
      'icon': Icons.manage_search,
      'label': 'Audit Log',
      'widget': const _AuditLogTab()
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAdminEmail();
    _loadSummary();
  }

  Future<void> _loadAdminEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _adminEmail = user.email ?? 'Admin');
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  Future<void> _loadSummary() async {
    try {
      final fs = FirebaseFirestore.instance;
      int users = 0, pickups = 0, donations = 0, vendors = 0;
      await Future.wait([
        fs.collection('users').get().then((v) => users = v.size),
        fs.collection('pickup_requests').get().then((v) => pickups = v.size),
        fs.collection('donations').get().then((v) => donations = v.size),
        fs.collection('vendors').get().then((v) => vendors = v.size),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = {
          'users': users,
          'pickups': pickups,
          'donations': donations,
          'vendors': vendors,
        };
        _loadingSummary = false;
      });
    } catch (e) {
      debugPrint('⚠️ Error loading summary: $e');
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 900;
    final currentTab = _tabs[_selectedIndex];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Row(children: [
          _buildSidebar(isWide),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(currentTab['label'] as String),
                const Divider(height: 1),
                _buildScrollableSummary(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: currentTab['widget'] as Widget,
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSidebar(bool isWide) {
    return NavigationRail(
      backgroundColor: Colors.green[700],
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) async {
        if (index == _tabs.length) {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
          return;
        }
        setState(() => _selectedIndex = index);
      },
      labelType:
          isWide ? NavigationRailLabelType.all : NavigationRailLabelType.none,
      leading: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          // Notification bell with unread badge
          StreamBuilder<int>(
            stream: NotificationService.unreadCountStream(),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.white, size: 36),
                  if (count > 0)
                    Positioned(
                      top: -4, right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                        child: Text('$count',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text('Admin',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isWide ? 16 : 13,
              )),
          const SizedBox(height: 10),
        ]),
      ),
      destinations: [
        ..._tabs.map((tab) => NavigationRailDestination(
              icon: Icon(tab['icon'] as IconData, color: Colors.white70),
              selectedIcon: Icon(tab['icon'] as IconData, color: Colors.white),
              label: Text(tab['label'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            )),
        const NavigationRailDestination(
          icon: Icon(Icons.logout, color: Colors.redAccent),
          selectedIcon: Icon(Icons.logout, color: Colors.white),
          label: Text('Logout',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(Icons.dashboard, color: Colors.green[800], size: 26),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800])),
          ]),
          Row(children: [
            if (_adminEmail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(_adminEmail,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500)),
              ),
            IconButton(
              tooltip: 'Refresh Summary',
              icon: const Icon(Icons.refresh, color: Colors.green),
              onPressed: () async {
                setState(() => _loadingSummary = true);
                await _loadSummary();
              },
            ),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFCCEBC5),
              child: Icon(Icons.person, color: Colors.green),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildScrollableSummary() {
    if (_loadingSummary) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: List.generate(
              4,
              (_) => Container(
                    height: 75,
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  )),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        _summaryCard(Icons.people, 'Users', _summary['users'].toString()),
        const SizedBox(width: 12),
        _summaryCard(
            Icons.recycling, 'Pickups', _summary['pickups'].toString()),
        const SizedBox(width: 12),
        _summaryCard(Icons.volunteer_activism, 'Donations',
            _summary['donations'].toString()),
        const SizedBox(width: 12),
        _summaryCard(Icons.store, 'Vendors', _summary['vendors'].toString()),
      ]),
    );
  }

  Widget _summaryCard(IconData icon, String title, String value) {
    return Container(
      width: 140,
      height: 75,
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 3))
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.green[700], size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87)),
        Text(title,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications Tab — shows admin_notifications collection in real-time
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('New Requests & Donations',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Mark All Read'),
                onPressed: () => NotificationService.markAllRead(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: NotificationService.notificationsStream(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No notifications yet',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final isUnread = !(data['read'] as bool? ?? false);
                  final type = (data['type'] ?? '').toString();
                  final title = (data['title'] ?? 'Notification').toString();
                  final body = (data['body'] ?? '').toString();
                  final ts = data['timestamp'] as Timestamp?;
                  final timeStr = ts != null
                      ? _formatTime(ts.toDate())
                      : '';

                  return Card(
                    color: isUnread ? Colors.green[50] : Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: isUnread
                          ? BorderSide(color: Colors.green.shade300, width: 1)
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: type == 'new_pickup'
                            ? Colors.green[100]
                            : Colors.blue[100],
                        child: Icon(
                          type == 'new_pickup'
                              ? Icons.local_shipping
                              : Icons.volunteer_activism,
                          color: type == 'new_pickup'
                              ? Colors.green[700]
                              : Colors.blue[700],
                          size: 20,
                        ),
                      ),
                      title: Text(title,
                          style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(body,
                              style: const TextStyle(fontSize: 12)),
                          if (timeStr.isNotEmpty)
                            Text(timeStr,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                      trailing: isUnread
                          ? IconButton(
                              icon: const Icon(Icons.check_circle_outline,
                                  color: Colors.green, size: 20),
                              tooltip: 'Mark read',
                              onPressed: () =>
                                  NotificationService.markRead(doc.id),
                            )
                          : const Icon(Icons.check_circle,
                              color: Colors.grey, size: 18),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audit Log Tab — shows request_history + donation_history merged
// ─────────────────────────────────────────────────────────────────────────────
class _AuditLogTab extends StatelessWidget {
  const _AuditLogTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(
          labelColor: Colors.black87,
          indicatorColor: Colors.green,
          tabs: [
            Tab(text: 'Pickup History'),
            Tab(text: 'Donation History'),
          ],
        ),
        Expanded(
            child: TabBarView(children: [
          _historyList('request_history', 'requestId'),
          _historyList('donation_history', 'donationId'),
        ])),
      ]),
    );
  }

  Widget _historyList(String collection, String idField) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No history yet'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            final dateStr = ts != null
                ? DateFormat('dd MMM yyyy  HH:mm').format(ts.toDate())
                : '';
            final oldS = data['oldStatus'] ?? '';
            final newS = data['newStatus'] ?? '';
            final by = data['changedByEmail'] ?? data['changedByUid'] ?? '?';
            final rid = (data[idField] ?? '').toString();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: newS == 'Completed' || newS == 'Collected'
                      ? Colors.green[100]
                      : newS == 'Cancelled' || newS == 'Rejected'
                          ? Colors.red[100]
                          : Colors.orange[100],
                  child: Icon(
                    newS == 'Completed' || newS == 'Collected'
                        ? Icons.check_circle
                        : newS == 'Cancelled'
                            ? Icons.cancel
                            : Icons.update,
                    color: newS == 'Completed' || newS == 'Collected'
                        ? Colors.green
                        : newS == 'Cancelled'
                            ? Colors.red
                            : Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(
                  '$oldS → $newS',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rid.isNotEmpty)
                      Text('ID: ${rid.substring(0, rid.length.clamp(0, 10))}…',
                          style: const TextStyle(fontSize: 11)),
                    Text('By: $by', style: const TextStyle(fontSize: 11)),
                    if (dateStr.isNotEmpty)
                      Text(dateStr,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
