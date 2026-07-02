// lib/screens/user/home_demo_banner.dart
import 'package:flutter/material.dart';
import '../../widgets/banner_slider.dart';

class HomeDemoBanner extends StatelessWidget {
  const HomeDemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Example banner images (mix of http and storage paths)
    final images = <String>[
      // http link example:
      'https://picsum.photos/1200/600?image=1067',
      // supabase/storage path example (will be normalized by normalizeUrl):
      'banners/sample_banner_1.jpg',
      // another http:
      'https://picsum.photos/1200/600?image=1025',
    ];

    final links = <String>[
      'https://example.com/promo1',
      '', // no link for second banner
      'https://example.com/promo3',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Banner Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            BannerSlider(images: images, links: links),
            const SizedBox(height: 24),
            const Text('Below the banner you can add other widgets...'),
          ],
        ),
      ),
    );
  }
}
