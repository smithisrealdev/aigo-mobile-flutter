import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Responsive image gallery for AI chat messages.
/// Matches web's ChatImageGallery.tsx behavior.
class ChatImageGallery extends StatelessWidget {
  final List<String> imageUrls;

  const ChatImageGallery({super.key, required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    final validUrls = imageUrls.where((u) => u.isNotEmpty).toList();
    if (validUrls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = _columnCount(validUrls.length);
          final spacing = 8.0;
          final itemWidth = (constraints.maxWidth - (cols - 1) * spacing) / cols;
          final itemHeight = validUrls.length == 1 ? itemWidth * 0.6 : itemWidth;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: validUrls.map((url) => _ImageTile(
              url: url,
              width: itemWidth,
              height: itemHeight,
              onTap: () => _showFullImage(context, url, validUrls),
            )).toList(),
          );
        },
      ),
    );
  }

  int _columnCount(int count) {
    if (count == 1) return 1;
    if (count <= 2) return 2;
    return 3;
  }

  void _showFullImage(BuildContext context, String initialUrl, List<String> allUrls) {
    final initialIndex = allUrls.indexOf(initialUrl);
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _FullImageViewer(
        urls: allUrls,
        initialIndex: initialIndex,
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _ImageTile({
    required this.url,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: height,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => _ShimmerPlaceholder(
              width: width,
              height: height,
            ),
            errorWidget: (_, __, ___) => Container(
              color: const Color(0xFFF3F4F6),
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Color(0xFF9CA3AF),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;

  const _ShimmerPlaceholder({required this.width, required this.height});

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade800 : const Color(0xFFE5E7EB);
    final hi = isDark ? Colors.grey.shade700 : const Color(0xFFF3F4F6);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
            end: Alignment(-1.0 + 2.0 * _ctrl.value + 1, 0),
            colors: [base, hi, base],
          ),
        ),
      ),
    );
  }
}

class _FullImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _FullImageViewer({required this.urls, required this.initialIndex});

  @override
  State<_FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<_FullImageViewer> {
  late PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image pages
        PageView.builder(
          controller: _pageController,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (ctx, i) => InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.urls[i],
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        // Close button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black26,
            ),
          ),
        ),
        // Page indicator
        if (widget.urls.length > 1)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.urls.length, (i) => Container(
                width: i == _current ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _current ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          ),
      ],
    );
  }
}
