//lib/widgets/service_grid.dart
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
    // Desktop: more columns + bigger cards
    // Tablet: 5 cols
    // Mobile: 4 cols
    final int crossCount;
    final double iconSize;
    final double fontSize;
    final double iconContainerSize;

    if (screenWidth > 1100) {
      crossCount = 8; // all in one row on very wide screens
      iconSize = 28;
      fontSize = 12;
      iconContainerSize = 56;
    } else if (screenWidth > 900) {
      crossCount = 4;
      iconSize = 30;
      fontSize = 13;
      iconContainerSize = 60;
    } else if (screenWidth > 500) {
      crossCount = 4;
      iconSize = 26;
      fontSize = 11;
      iconContainerSize = 52;
    } else {
      crossCount = 4;
      iconSize = 24;
      fontSize = 11;
      iconContainerSize = 48;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 900 ? 0 : 16,
        vertical: 4,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: screenWidth > 900 ? 14 : 10,
        mainAxisSpacing: screenWidth > 900 ? 14 : 10,
        childAspectRatio: screenWidth > 900 ? 1.0 : 0.95,
      ),
      itemCount: services.length,
      itemBuilder: (_, i) {
        final s = services[i];
        return Material(
          color: s.color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => onTap(s.route),
            borderRadius: BorderRadius.circular(14),
            splashColor: s.color.withOpacity(0.18),
            highlightColor: s.color.withOpacity(0.08),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: s.color.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: iconContainerSize,
                    height: iconContainerSize,
                    decoration: BoxDecoration(
                      color: s.color.withOpacity(0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(s.icon, color: s.color, size: iconSize),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      s.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: s.color,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
