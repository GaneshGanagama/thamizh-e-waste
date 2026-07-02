import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openWebPolicy() async {
    const webUrl = 'https://ecomeel.in/privacy-policy.html';
    final uri = Uri.parse(webUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('⚠️ Could not open $webUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last Updated: October 2025',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thamizh E-Waste Privacy Policy',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Thamizh E-Waste respects your privacy and is committed to protecting your personal data. '
              'This Privacy Policy explains what data we collect, how we use it, and how you can control it.',
              style:
                  TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            _sectionTitle('1. Information We Collect'),
            const Text(
              '• Name, email, and phone number during sign-up or service booking.\n'
              '• Address and pickup location for e-waste collection.\n'
              '• Images or documents you voluntarily upload (e.g., receipts, proof of recycling).',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            _sectionTitle('2. How We Use Your Data'),
            const Text(
              '• To process pickup, donation, or recycling requests.\n'
              '• To send service confirmations, reminders, or reward updates.\n'
              '• To analyze and improve our platform for better user experience.\n'
              '• To comply with local environmental laws and safety guidelines.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            _sectionTitle('3. Data Protection'),
            const Text(
              'All user data is stored securely on Firebase servers using encryption and authenticated access. '
              'We never sell or rent your data to third parties.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            _sectionTitle('4. Your Rights'),
            const Text(
              'You have complete control over your data. You may request at any time:\n'
              '• Deletion of your account\n'
              '• Removal of your uploaded data or images\n'
              '• Correction of incorrect details',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            _sectionTitle('5. Contact Us'),
            const Text(
              'If you have any concerns or requests regarding this policy, please reach out to us:',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Text(
                '📧 thamizhewaste@gmail.com\n'
                '📞 +91 97875 55916\n'
                '📍 Thamizh Road No.72, SIDCO Industrial Estate,\n'
                '    Veppur Taluk, Cuddalore District – 606304',
                style: TextStyle(height: 1.5, fontSize: 15),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: ElevatedButton.icon(
                onPressed: _openWebPolicy,
                icon: const Icon(Icons.open_in_new),
                label: const Text('View Full Policy Online'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                '© 2025 Thamizh E-Waste | All Rights Reserved',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      );
}
