import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _certificates = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadCertificates();
    _searchController.addListener(_filterCertificates);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadCertificates() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final snapshot = await _firestore
          .collection('certificates')
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) return;

      setState(() {
        _certificates = snapshot.docs;
        _filtered = snapshot.docs;
        _loading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _firebaseError(e);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _filterCertificates() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filtered = _certificates;
      });
      return;
    }

    setState(() {
      _filtered = _certificates.where((doc) {
        final data = doc.data();

        final certificateId =
            (data['certificateId'] ?? doc.id).toString().toLowerCase();

        final userName =
            (data['userName'] ?? data['name'] ?? '').toString().toLowerCase();

        final email = (data['email'] ?? '').toString().toLowerCase();

        final userId = (data['userId'] ?? '').toString().toLowerCase();

        return certificateId.contains(query) ||
            userName.contains(query) ||
            email.contains(query) ||
            userId.contains(query);
      }).toList();
    });
  }

  // ============================================================
  // VIEW CERTIFICATE
  // ============================================================

  void _viewCertificate(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.verified,
                color: Colors.green,
              ),
              SizedBox(width: 10),
              Text('Certificate Details'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detail(
                    'Certificate ID',
                    (data['certificateId'] ?? doc.id).toString(),
                  ),
                  _detail(
                    'User',
                    (data['userName'] ?? data['name'] ?? 'Unknown').toString(),
                  ),
                  _detail(
                    'Email',
                    (data['email'] ?? 'Not available').toString(),
                  ),
                  _detail(
                    'User ID',
                    (data['userId'] ?? 'Not available').toString(),
                  ),
                  _detail(
                    'Total Recycled',
                    '${data['totalKg'] ?? data['weight'] ?? 0} kg',
                  ),
                  _detail(
                    'Reward',
                    '${data['totalReward'] ?? data['reward'] ?? 0}',
                  ),
                  _detail(
                    'Status',
                    (data['status'] ?? 'valid').toString(),
                  ),
                  _detail(
                    'Created',
                    _formatDate(data['createdAt'] ?? data['date']),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _detail(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Not available';

    if (value is Timestamp) {
      final date = value.toDate();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    return value.toString();
  }

  String _firebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Please check the Firestore rules '
            'for the certificates collection.';
      case 'failed-precondition':
        return 'Firestore needs an index for this query.';
      case 'unavailable':
        return 'Firebase is temporarily unavailable. '
            'Check your internet connection and try again.';
      default:
        return e.message ?? 'Unable to load certificates.';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E5E5),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.picture_as_pdf,
            color: Color(0xFF2E8B3C),
            size: 30,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Certificates',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E8B3C),
              ),
            ),
          ),

          // REFRESH
          Tooltip(
            message: 'Refresh certificates',
            child: IconButton(
              onPressed: _loading ? null : _loadCertificates,
              icon: const Icon(Icons.refresh),
            ),
          ),

          const SizedBox(width: 8),

          // ADMIN
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 19,
                  color: Color(0xFF2E8B3C),
                ),
                SizedBox(width: 6),
                Text(
                  'Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E8B3C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSearch(),
          const SizedBox(height: 18),
          Expanded(
            child: _buildCertificateContent(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search certificate ID, user name, email...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildCertificateContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 50,
                color: Colors.orange,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to load certificates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadCertificates,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _certificates.isEmpty
                  ? 'No certificates found'
                  : 'No certificates match your search',
              style: TextStyle(
                fontSize: 17,
                color: Colors.grey.shade700,
              ),
            ),
            if (_certificates.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Certificates will appear here after completed recycling requests.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return _buildTable();
  }

  // ============================================================
  // TABLE
  // ============================================================

  Widget _buildTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 28,
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFFE8F5E9),
          ),
          columns: const [
            DataColumn(label: Text('Certificate ID')),
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Weight')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _filtered.map((doc) {
            final data = doc.data();

            final certificateId = (data['certificateId'] ?? doc.id).toString();

            final userName =
                (data['userName'] ?? data['name'] ?? 'Unknown').toString();

            final email = (data['email'] ?? '-').toString();

            final weight = '${data['totalKg'] ?? data['weight'] ?? 0} kg';

            final status = (data['status'] ?? 'valid').toString();

            final date = _formatDate(data['createdAt'] ?? data['date']);

            return DataRow(
              cells: [
                DataCell(
                  SelectableText(
                    certificateId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(Text(userName)),
                DataCell(Text(email)),
                DataCell(Text(weight)),
                DataCell(_statusChip(status)),
                DataCell(Text(date)),
                DataCell(
                  IconButton(
                    tooltip: 'View certificate',
                    onPressed: () => _viewCertificate(doc),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();

    Color background;
    Color foreground;

    if (normalized == 'valid' ||
        normalized == 'approved' ||
        normalized == 'completed') {
      background = Colors.green.shade100;
      foreground = Colors.green.shade800;
    } else if (normalized == 'pending') {
      background = Colors.orange.shade100;
      foreground = Colors.orange.shade800;
    } else {
      background = Colors.grey.shade200;
      foreground = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
