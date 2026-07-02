// lib/widgets/mission_section.dart
import 'package:flutter/material.dart';

class MissionSection extends StatelessWidget {
  const MissionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: Colors.green[700], size: 22),
              const SizedBox(width: 8),
              Text(
                'Our Mission',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Ecomeel connects communities with responsible e-waste recyclers. '
            'We make it easy to dispose of electronic waste safely, earn rewards, '
            'and protect our environment for future generations.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
