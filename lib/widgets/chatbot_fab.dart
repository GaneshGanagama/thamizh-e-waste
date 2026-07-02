// lib/widgets/chatbot_fab.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatBotFAB extends StatelessWidget {
  const ChatBotFAB({super.key});

  Future<void> _openChat(BuildContext context) async {
    // Replace with your actual chatbot URL or use a dialog
    final uri = Uri.parse('https://ecomeel.in/chat');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Help & Support'),
            content: const Text(
              'For support, email us at:\nsupport@ecomeel.in\n\nOr call: +91-XXXXXXXXXX',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'chatbot',
      backgroundColor: Colors.green[700],
      tooltip: 'Help & Chat',
      onPressed: () => _openChat(context),
      child: const Icon(Icons.chat, color: Colors.white),
    );
  }
}
