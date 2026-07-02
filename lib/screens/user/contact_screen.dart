import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  // Contact Info
  final String phone = '9787555916';
  final String email = 'thamizhewaste@gmail.com';
  final String address =
      'Thamizh Road No. 72, SIDCO Industrial Estate,\nPeriyanesalur, Veppur Taluk,\nCuddalore District - 606304';
  final String whatsappUrl = 'https://wa.me/919787555916';
  final String mapUrl =
      'https://www.google.com/maps/search/?api=1&query=Thamizh+E-Waste+Cuddalore';
  final String privacyUrl = 'https://ecomeel.in/privacy-policy';

  const ContactScreen({super.key});

  // --------- Launch Helpers ----------
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("⚠️ Could not launch $urlString");
      }
    } catch (e) {
      debugPrint("❌ Error launching $urlString: $e");
    }
  }

  void _launchPhone() => _launchUrl('tel:9787555916');

  void _launchEmail() => _launchUrl(
      'mailto:thamizhewaste@gmail.com?subject=Customer%20Support%20Request&body=Hello%20Team%20Thamizh%20E-Waste,');

  void _launchWhatsApp() => _launchUrl('https://wa.me/919787555916');

  void _launchMap() => _launchUrl(
      'https://www.google.com/maps/search/?api=1&query=Thamizh+E-Waste+Cuddalore');

  void _launchPrivacy() => _launchUrl('https://ecomeel.in/privacy-policy');

  // --------- UI Build ----------
  @override
  Widget build(BuildContext context) {
    final Color accentColor = Colors.green[700]!;
    final TextStyle titleStyle = TextStyle(
        fontWeight: FontWeight.bold, fontSize: 16, color: accentColor);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Contact Us"),
        backgroundColor: accentColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              "We’re here to help 💚",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Have questions, feedback, or need assistance? Reach us anytime!",
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Contact Cards
            _contactCard(
              icon: Icons.phone,
              title: "Call Us",
              subtitle: phone,
              color: Colors.green,
              onTap: _launchPhone,
            ),
            _contactCard(
              icon: Icons.email,
              title: "Email",
              subtitle: email,
              color: Colors.blue,
              onTap: _launchEmail,
            ),
            _contactCard(
              icon: Icons.chat,
              title: "WhatsApp",
              subtitle: "Chat with our support team",
              color: Colors.teal,
              onTap: _launchWhatsApp,
            ),
            _contactCard(
              icon: Icons.location_on,
              title: "Office Address",
              subtitle: address,
              color: Colors.red,
              onTap: _launchMap,
            ),
            const SizedBox(height: 20),

            // Business Hours
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.access_time, color: Colors.orange),
                title: const Text("Business Hours"),
                subtitle: const Text(
                    "Monday - Saturday: 9:00 AM - 6:00 PM\nSunday: Closed"),
              ),
            ),
            const SizedBox(height: 20),

            // --- Privacy & Data Safety Section ---
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
              child: Column(
                children: [
                  const Text(
                    "🔒 Privacy & Data Safety",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "We value your privacy. Contact details shared via call, "
                    "email, or WhatsApp are used only to assist you and will "
                    "not be stored or shared with any third parties.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: Colors.black54, height: 1.4),
                  ),
                  TextButton.icon(
                    onPressed: _launchPrivacy,
                    icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                    label: const Text(
                      "Read Full Privacy Policy",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Footer
            Center(
              child: Column(
                children: const [
                  Text(
                    "© 2025 Thamizh E-Waste. All Rights Reserved.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------- Contact Card Widget ----------
  Widget _contactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.black87, fontSize: 13)),
        onTap: onTap,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
