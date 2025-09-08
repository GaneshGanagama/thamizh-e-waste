import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  final String phone = '9787555916';
  final String email = 'thamizhewaste@gmail.com';
  final String address =
      'Thamizh road number 72 Sidco Industrial Estate, Periyanesalur, Veppur Taluk, Cuddolore Dist -606304';
  final String whatsapp = 'https://wa.me/919787555916';

  const ContactScreen({super.key});

  void _launchPhone() async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _launchEmail() async {
    final Uri url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _launchWhatsApp() async {
    final Uri url = Uri.parse(whatsapp);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Contact Us")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Need help?",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.phone, color: Colors.green),
              title: Text("Call Us"),
              subtitle: Text(phone),
              onTap: _launchPhone,
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.email, color: Colors.blue),
              title: Text("Email"),
              subtitle: Text(email),
              onTap: _launchEmail,
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.chat, color: Colors.teal),
              title: Text("WhatsApp"),
              subtitle: Text("Chat with us"),
              onTap: _launchWhatsApp,
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.location_on, color: Colors.red),
              title: Text("Office Address"),
              subtitle: Text(address),
            ),
          ],
        ),
      ),
    );
  }
}
