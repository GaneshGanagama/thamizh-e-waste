// lib/screens/user/certificates_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CERTIFICATES SCREEN
//
// Logic:
//  • Every completed pickup_request gives the user ONE certificate immediately
//  • Each certificate is for that specific request (date, items, kg, reward)
//  • User can download/share any certificate as a PDF
//  • Milestone badges (Bronze/Silver/Gold) are shown as bonus achievements
//    based on total recycled kg — but do NOT block the basic certificate
// ─────────────────────────────────────────────────────────────────────────────

class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key});

  // ── Build PDF for a single completed request ──────────────────────────────
  pw.Document _buildPdf({
    required String userName,
    required String userEmail,
    required String requestId,
    required String dateStr,
    required double totalKg,
    required double reward,
    required List<String> itemLines,
  }) {
    final pdf = pw.Document();
    final issuedOn = DateFormat('dd MMMM yyyy').format(DateTime.now());
    final displayName = userName.isNotEmpty ? userName : userEmail;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Header bar
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 14),
            decoration: const pw.BoxDecoration(color: PdfColors.green800),
            child: pw.Text(
              'CERTIFICATE OF E-WASTE RECYCLING',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 28),

          pw.Text('This is to certify that',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
          pw.SizedBox(height: 10),

          // User name
          pw.Text(
            displayName,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(userEmail,
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          pw.SizedBox(height: 20),

          pw.Text(
            'has successfully recycled e-waste through Ecomeel.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 24),

          // Details box
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green200),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfRow('Request ID', requestId),
                _pdfRow('Date of Pickup', dateStr),
                _pdfRow('Total Weight', '${totalKg.toStringAsFixed(1)} kg'),
                _pdfRow('Estimated Reward', '₹${reward.toStringAsFixed(0)}'),
                if (itemLines.isNotEmpty)
                  _pdfRow('Items', itemLines.join(', ')),
              ],
            ),
          ),
          pw.SizedBox(height: 28),

          pw.Text(
            'Thank you for contributing to a cleaner, greener planet.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 13,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 40),

          // Footer
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Issued on: $issuedOn',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                pw.Text('Ecomeel — Thamizh E-Waste Pvt. Ltd.',
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('____________________',
                    style: const pw.TextStyle(color: PdfColors.grey600)),
                pw.Text('Authorized Signature',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ]),
            ],
          ),
        ],
      ),
    ));
    return pdf;
  }

  pw.Widget _pdfRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(children: [
      pw.SizedBox(
        width: 120,
        child: pw.Text('$label:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
      ),
      pw.Expanded(
        child: pw.Text(value,
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
      ),
    ]),
  );

  // ── Download a single request certificate ──────────────────────────────────
  Future<void> _download(BuildContext context, Map<String, dynamic> data, String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final items = (data['items'] as List<dynamic>? ?? []);
      double totalKg = 0;
      final itemLines = <String>[];
      for (final it in items) {
        final w = (it['weight'] as num? ?? 0).toDouble();
        totalKg += w;
        itemLines.add('${it['wasteType']} (${w}kg)');
      }

      final ts = data['timestamp'];
      String dateStr = 'N/A';
      if (ts is Timestamp) {
        dateStr = DateFormat('dd MMM yyyy').format(ts.toDate());
      }

      final pdf = _buildPdf(
        userName:   user?.displayName ?? '',
        userEmail:  user?.email ?? '',
        requestId:  docId.substring(0, 8).toUpperCase(),
        dateStr:    dateStr,
        totalKg:    totalKg,
        reward:     (data['totalReward'] as num? ?? 0).toDouble(),
        itemLines:  itemLines,
      );

      final bytes = await pdf.save();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _share(BuildContext context, Map<String, dynamic> data, String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final items = (data['items'] as List<dynamic>? ?? []);
      double totalKg = 0;
      final itemLines = <String>[];
      for (final it in items) {
        final w = (it['weight'] as num? ?? 0).toDouble();
        totalKg += w;
        itemLines.add('${it['wasteType']} (${w}kg)');
      }
      final ts = data['timestamp'];
      String dateStr = 'N/A';
      if (ts is Timestamp) {
        dateStr = DateFormat('dd MMM yyyy').format(ts.toDate());
      }
      final pdf = _buildPdf(
        userName:  user?.displayName ?? '',
        userEmail: user?.email ?? '',
        requestId: docId.substring(0, 8).toUpperCase(),
        dateStr:   dateStr,
        totalKg:   totalKg,
        reward:    (data['totalReward'] as num? ?? 0).toDouble(),
        itemLines: itemLines,
      );
      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'ecomeel_certificate_${docId.substring(0, 8)}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('Please log in to view certificates')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Certificates'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'My Pickups', icon: Icon(Icons.receipt_long, size: 18)),
              Tab(text: 'Milestones', icon: Icon(Icons.emoji_events, size: 18)),
            ],
          ),
        ),
        body: TabBarView(children: [
          _buildPickupCertificates(context, user),
          _buildMilestoneCertificates(context, user),
        ]),
      ),
    );
  }

  // ── Tab 1: One certificate per completed pickup ────────────────────────────
  Widget _buildPickupCertificates(BuildContext context, User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Completed')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No completed pickups yet',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text(
                    'Once admin marks your pickup as Completed,\nyour certificate will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;

            final ts = data['timestamp'];
            String dateStr = 'N/A';
            if (ts is Timestamp) {
              dateStr = DateFormat('dd MMM yyyy').format(ts.toDate());
            }

            final items = (data['items'] as List<dynamic>? ?? []);
            double totalKg = 0;
            for (final it in items) {
              totalKg += (it['weight'] as num? ?? 0).toDouble();
            }
            final reward = (data['totalReward'] as num? ?? 0).toDouble();
            final shortId = doc.id.substring(0, 8).toUpperCase();

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(Icons.verified, color: Colors.green[700], size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Certificate #$shortId',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(dateStr,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Completed',
                            style: TextStyle(
                                color: Colors.green[800],
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(children: [
                      _statChip(Icons.scale, '${totalKg.toStringAsFixed(1)} kg',
                          Colors.blue),
                      const SizedBox(width: 8),
                      _statChip(Icons.currency_rupee,
                          '₹${reward.toStringAsFixed(0)}', Colors.orange),
                      const SizedBox(width: 8),
                      _statChip(Icons.inventory_2,
                          '${items.length} item${items.length == 1 ? "" : "s"}',
                          Colors.purple),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _share(context, data, doc.id),
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _download(context, data, doc.id),
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Download'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

  // ── Tab 2: Milestone certificates (Bronze/Silver/Gold) ─────────────────────
  Widget _buildMilestoneCertificates(BuildContext context, User user) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('pickup_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Completed')
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        double totalKg = 0;
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            for (final it in (data['items'] as List<dynamic>? ?? [])) {
              totalKg += (it['weight'] as num? ?? 0).toDouble();
            }
          }
        }

        const milestones = [
          {'level': 'Bronze', 'kg': 10,  'icon': '🥉', 'color': 0xFF8D6E63},
          {'level': 'Silver', 'kg': 25,  'icon': '🥈', 'color': 0xFF78909C},
          {'level': 'Gold',   'kg': 50,  'icon': '🥇', 'color': 0xFFFFA000},
          {'level': 'Green Hero', 'kg': 100, 'icon': '🌍', 'color': 0xFF2E7D32},
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                Icon(Icons.recycling, color: Colors.green[700], size: 28),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Recycled',
                      style: TextStyle(
                          fontSize: 12, color: Colors.green[700])),
                  Text('${totalKg.toStringAsFixed(1)} kg',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800])),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            ...milestones.map((m) {
              final req      = m['kg'] as int;
              final level    = m['level'] as String;
              final emoji    = m['icon'] as String;
              final color    = Color(m['color'] as int);
              final unlocked = totalKg >= req;
              final progress = (totalKg / req).clamp(0.0, 1.0);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(emoji, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$level Certificate',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: unlocked ? color : Colors.grey[700])),
                              Text('Recycle $req kg to unlock',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                        if (unlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Unlocked',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                              unlocked ? color : Colors.grey.shade400),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unlocked
                            ? '${totalKg.toStringAsFixed(1)} / $req kg ✓'
                            : '${totalKg.toStringAsFixed(1)} / $req kg  (${(req - totalKg).toStringAsFixed(1)} kg to go)',
                        style: TextStyle(
                            fontSize: 11,
                            color: unlocked ? color : Colors.grey[500]),
                      ),
                      if (unlocked) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  final u = FirebaseAuth.instance.currentUser;
                                  final pdf = _buildMilestonePdf(
                                    level: level,
                                    kg: totalKg.toInt(),
                                    userName: u?.displayName ?? '',
                                    userEmail: u?.email ?? '',
                                  );
                                  final bytes = await pdf.save();
                                  await Printing.layoutPdf(
                                      onLayout: (_) async => bytes);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')));
                                }
                              },
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Download'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  pw.Document _buildMilestonePdf({
    required String level,
    required int kg,
    required String userName,
    required String userEmail,
  }) {
    final pdf = pw.Document();
    final issuedOn = DateFormat('dd MMMM yyyy').format(DateTime.now());
    final displayName = userName.isNotEmpty ? userName : userEmail;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 16),
            decoration: const pw.BoxDecoration(color: PdfColors.green800),
            child: pw.Text(
              '$level RECYCLER CERTIFICATE',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Text('This certifies that',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Text(displayName,
              style: pw.TextStyle(
                  fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
          pw.SizedBox(height: 8),
          pw.Text(userEmail,
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          pw.SizedBox(height: 24),
          pw.Text(
            'has achieved the $level milestone by recycling $kg kg of e-waste\nthrough Ecomeel — Thamizh E-Waste Pvt. Ltd.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 15),
          ),
          pw.SizedBox(height: 40),
          pw.Text('Issued on $issuedOn',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          pw.SizedBox(height: 60),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Ecomeel — Thamizh E-Waste Pvt. Ltd.',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('____________________'),
              pw.Text('Authorized Signature',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ]),
          ]),
        ],
      ),
    ));
    return pdf;
  }
}
