// lib/widgets/service_grid.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ServiceGrid extends StatelessWidget {
  final List<ServiceItem> services;
  final double screenWidth;
  final void Function(String route) onTap;

  const ServiceGrid({
    super.key,
    required this.services,
    required this.screenWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 4 columns on wide screens (tablet/web), 4 on phone too
    // so all 8 items fit neatly in 2 rows
    final crossCount = screenWidth > 500 ? 4 : 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Our Services',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            // Fixed aspect ratio — prevents any card from being taller
            childAspectRatio: 0.95,
          ),
          itemCount: services.length,
          itemBuilder: (_, i) {
            final s = services[i];
            return GestureDetector(
              onTap: () => onTap(s.route),
              child: Container(
                decoration: BoxDecoration(
                  color: s.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: s.color.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s.icon, color: s.color, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: s.color,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
