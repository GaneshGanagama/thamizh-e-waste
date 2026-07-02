import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class BannerSlider extends StatefulWidget {
  final List<String> images;
  final List<String>? links;

  const BannerSlider({
    super.key,
    required this.images,
    this.links,
  });

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  int _current = 0;

  bool _isNetwork(String v) =>
      v.startsWith('http://') || v.startsWith('https://');

  Future<void> _onBannerTap(int index) async {
    if (widget.links == null || index >= widget.links!.length) return;
    final link = widget.links![index];
    if (link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(
      uri,
      mode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No banners available')),
      );
    }

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: widget.images.length,
          itemBuilder: (context, index, realIndex) {
            final img = widget.images[index];
            return GestureDetector(
              onTap: () => _onBannerTap(index),
              child: _BannerImage(src: img),
            );
          },
          options: CarouselOptions(
            // aspectRatio drives the height automatically from screen width
            // 16:9 is the standard for banner/hero images on web & mobile
            aspectRatio: 16 / 6,
            viewportFraction: 1.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayCurve: Curves.easeInOut,
            autoPlayAnimationDuration: const Duration(milliseconds: 600),
            enlargeCenterPage: false,
            onPageChanged: (i, _) => setState(() => _current = i),
          ),
        ),

        const SizedBox(height: 8),

        // Animated dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.images.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _current == i
                    ? Colors.green[700]
                    : Colors.grey.withOpacity(0.35),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BannerImage — renders one banner respecting its natural aspect ratio.
// For network images: loads naturally, never stretches, letterboxes if needed.
// For asset images: same behaviour.
// ─────────────────────────────────────────────────────────────────────────────
class _BannerImage extends StatelessWidget {
  final String src;
  const _BannerImage({required this.src});

  bool get _isNetwork =>
      src.startsWith('http://') || src.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        color: Colors.grey[100],
        child: _isNetwork ? _networkImage() : _assetImage(),
      ),
    );
  }

  Widget _networkImage() {
    return CachedNetworkImage(
      imageUrl: src,
      // contain = show full image at its natural ratio, no cropping, no stretch
      fit: BoxFit.contain,
      width: double.infinity,
      fadeInDuration: const Duration(milliseconds: 300),
      placeholder: (_, __) => const _BannerPlaceholder(),
      errorWidget: (_, __, ___) => const _BannerError(),
    );
  }

  Widget _assetImage() {
    return Image.asset(
      src,
      fit: BoxFit.contain,
      width: double.infinity,
      errorBuilder: (_, __, ___) => const _BannerError(),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 36, color: Colors.grey[400]),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey[300],
                color: Colors.green[400],
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerError extends StatelessWidget {
  const _BannerError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                size: 36, color: Colors.grey[400]),
            const SizedBox(height: 6),
            Text(
              'Image unavailable',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
