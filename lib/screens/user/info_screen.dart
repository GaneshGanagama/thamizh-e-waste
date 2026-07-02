// lib/screens/user/info_screen.dart
import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  // FIX: static const so the const constructor is valid
  static const List<Map<String, String>> infoList = [
    {
      'title': 'Why Recycle E-Waste?',
      'desc':
          'E-waste contains toxic substances like lead and mercury. Recycling prevents environmental damage and supports reuse of valuable metals.',
    },
    {
      'title': 'Accepted E-Waste Items',
      'desc':
          'We collect mobile phones, laptops, televisions, batteries, printers, and other electronics.',
    },
    {
      'title': "Don't Throw in Dustbin!",
      'desc':
          'Improper disposal of electronics contaminates soil and water. Always use certified collection services or drop-off points.',
    },
    {
      'title': 'Get Certified Disposal',
      'desc':
          'We ensure e-waste is processed safely and legally under pollution control board norms. Ask for your digital certificate.',
    },
    {
      'title': 'Save the Planet',
      'desc':
          'Your action helps reduce carbon footprint, protect the environment, and promote a circular economy. Join the green revolution!',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Waste Info & Tips'),
        backgroundColor: Colors.green[700],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: infoList.length,
        itemBuilder: (context, index) {
          final info = infoList[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info['title']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    info['desc']!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
