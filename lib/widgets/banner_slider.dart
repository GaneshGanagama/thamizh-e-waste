// lib/widgets/banner_slider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BannerSlider extends StatefulWidget {
  final List<String> images;
  final List<String> links;

  const BannerSlider({
    super.key,
    required this.images,
    this.links = const [],
  });

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  late final PageController _pc;
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        final next = (_current + 1) % widget.images.length;
        _pc.animateToPage(next,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  Future<void> _onTap(int index) async {
    final link = index < widget.links.length ? widget.links[index].trim() : '';
    if (link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Desktop: contained width, matches the same max-width column
    // used by every other section on the home page (see home_screen.dart _kMaxWidth).
    final isDesktop = width > 900;
    const maxContentWidth = 1100.0;
    final hPadding = isDesktop ? 0.0 : 12.0;

    // Mobile banners were designed roughly 16:9-ish; keep that ratio so
    // BoxFit.cover never has to crop away large parts of the image.
    // Desktop gets a slightly wider, shorter ratio so it reads as a "hero"
    // strip instead of a tall wall of image.
    final aspectRatio = isDesktop ? 21 / 9 : 16 / 9;

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? maxContentWidth : double.infinity,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: PageView.builder(
                    controller: _pc,
                    itemCount: widget.images.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (_, i) {
                      final src = widget.images[i];
                      final isNetwork = src.startsWith('http');
                      return GestureDetector(
                        onTap: () => _onTap(i),
                        child: isNetwork
                            ? Image.network(
                                src,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => _placeholder(),
                              )
                            : Image.asset(
                                src,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => _placeholder(),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _current == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _current == i
                      ? Colors.green[700]
                      : Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(child: Icon(Icons.image_not_supported, size: 40)),
    );
  }
}
