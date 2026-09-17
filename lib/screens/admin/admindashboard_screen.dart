// lib/screens/admin/admindashboard_screen.dart

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
import 'certificates_tab.dart' as admin_certificates;
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

  // FIXED: moved list to build() so context is available if needed,
  // and fixed both CertificatesTab → CertificatesScreen and added
  // missing widget for Drop Points tab.
  List<Map<String, dynamic>> get _tabs => [
        {
          'icon': Icons.list_alt,
          'label': 'Requests',
          'widget': const RequestsTab(),
        },
        {
          'icon': Icons.volunteer_activism,
          'label': 'Donations',
          'widget': const DonationsTab(),
        },
        {
          'icon': Icons.price_check,
          'label': 'Scrap Prices',
          'widget': const ScrapPricesTab(),
        },
        {
          'icon': Icons.image,
          'label': 'Banners',
          'widget': const BannersTab(),
        },
        {
          'icon': Icons.campaign,
          'label': 'Announcements',
          'widget': const AnnouncementsTab(),
        },
        {
          'icon': Icons.lightbulb,
          'label': 'Awareness',
          'widget': const AwarenessTab(),
        },
        {
          'icon': Icons.store,
          'label': 'Vendors',
          'widget': const VendorsTab(),
        },
        {
          'icon': Icons.history,
          'label': 'Vendor History',
          'widget': const VendorHistoryTab(),
        },
        {
          'icon': Icons.picture_as_pdf,
          'label': 'Certificates',
          // FIXED: was CertificatesTab() — correct class name is CertificatesScreen
          'widget': const admin_certificates.CertificatesTab(),
          //'widget': const admin_certificates.CertificatesScreen(),
        },
        {
          'icon': Icons.location_on,
          'label': 'Drop Points',
          // FIXED: was missing widget entirely — caused crash when tapped
          'widget': const DropPointsTab(),
        },
        {
          'icon': Icons.eco,
          'label': 'Impact',
          'widget': const ImpactSettingsTab(),
        },
        {
          'icon': Icons.manage_search,
          'label': 'Audit Log',
          'widget': const _AuditLogTab(),
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
      if (!mounted) return;
      setState(() {
        _adminEmail = user.email ?? 'Admin';
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  Future<void> _loadSummary() async {
    try {
      final fs = FirebaseFirestore.instance;
      int users = 0, pickups = 0, donations = 0, vendors = 0;

      await Future.wait([
        fs.collection('users').get().then((s) => users = s.size),
        fs.collection('pickup_requests').get().then((s) => pickups = s.size),
        fs.collection('donations').get().then((s) => donations = s.size),
        fs.collection('vendors').get().then((s) => vendors = s.size),
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
      debugPrint('Error loading admin summary: $e');
      if (!mounted) return;
      setState(() => _loadingSummary = false);
    }
  }

  Future<void> _refreshSummary() async {
    if (!mounted) return;
    setState(() => _loadingSummary = true);
    await _loadSummary();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 900;
    final tabs = _tabs; // evaluated once per build
    final currentTab = tabs[_selectedIndex];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(isWide, tabs),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isWide, List<Map<String, dynamic>> tabs) {
    return NavigationRail(
      backgroundColor: Colors.green[700],
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) async {
        if (index == tabs.length) {
          await _logout();
          return;
        }
        if (!mounted) return;
        setState(() => _selectedIndex = index);
      },
      labelType:
          isWide ? NavigationRailLabelType.all : NavigationRailLabelType.none,
      leading: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            StreamBuilder<int>(
              stream: NotificationService.unreadCountStream(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 36),
                    if (count > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Text('$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
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
                    fontSize: isWide ? 16 : 13)),
            const SizedBox(height: 10),
          ],
        ),
      ),
      destinations: [
        ...tabs.map((tab) => NavigationRailDestination(
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
              onPressed: _refreshSummary,
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
              height: 88,
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
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
      height: 88,
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 3))
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.green[700], size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87)),
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Audit Log Tab
// ─────────────────────────────────────────────
class _AuditLogTab extends StatelessWidget {
  const _AuditLogTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.black87,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: 'Pickup History'),
              Tab(text: 'Donation History'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _historyList('request_history', 'requestId'),
                _historyList('donation_history', 'donationId'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyList(String collection, String idField) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Unable to load history',
                  style: TextStyle(color: Colors.grey[600])));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No history yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            final dateStr = ts != null
                ? DateFormat('dd MMM yyyy  HH:mm').format(ts.toDate())
                : '';
            final oldStatus = data['oldStatus'] ?? '';
            final newStatus = data['newStatus'] ?? '';
            final changedBy =
                data['changedByEmail'] ?? data['changedByUid'] ?? '?';
            final recordId = (data[idField] ?? '').toString();
            final shortId =
                recordId.length > 10 ? recordId.substring(0, 10) : recordId;
            final isCompleted =
                newStatus == 'Completed' || newStatus == 'Collected';
            final isCancelled =
                newStatus == 'Cancelled' || newStatus == 'Rejected';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCompleted
                      ? Colors.green[100]
                      : isCancelled
                          ? Colors.red[100]
                          : Colors.orange[100],
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle
                        : isCancelled
                            ? Icons.cancel
                            : Icons.update,
                    color: isCompleted
                        ? Colors.green
                        : isCancelled
                            ? Colors.red
                            : Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text('$oldStatus → $newStatus',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recordId.isNotEmpty)
                      Text('ID: $shortId…',
                          style: const TextStyle(fontSize: 11)),
                    Text('By: $changedBy',
                        style: const TextStyle(fontSize: 11)),
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
