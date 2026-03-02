import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

const Color _brandBlue = Color(0xFF1A5EFF);
const Color _dotInactive = Color(0xFFE6E6E6);

/// Photo carousel with dots indicator and full-screen tap.
class PlacePhotoCarousel extends StatefulWidget {
  final List<String> photoUrls;
  final String? placeName;
  final double height;
  final double borderRadius;

  const PlacePhotoCarousel({
    super.key,
    required this.photoUrls,
    this.placeName,
    this.height = 200,
    this.borderRadius = 16,
  });

  @override
  State<PlacePhotoCarousel> createState() => _PlacePhotoCarouselState();
}

class _PlacePhotoCarouselState extends State<PlacePhotoCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            height: widget.height,
            child: PageView.builder(
              itemCount: widget.photoUrls.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, i) {
                final url = widget.photoUrls[i];
                final tag = 'photo_${widget.placeName ?? ''}_$i';
                return GestureDetector(
                  onTap: () => _openFullScreen(context, i),
                  child: Hero(
                    tag: tag,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _ShimmerBox(
                        height: widget.height,
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: _dotInactive,
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.photoUrls.length > 1) ...[
          const SizedBox(height: 8),
          _DotsIndicator(
            count: widget.photoUrls.length,
            current: _current,
          ),
        ],
      ],
    );
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          photoUrls: widget.photoUrls,
          placeName: widget.placeName,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> photoUrls;
  final String? placeName;
  final int initialIndex;

  const _FullScreenGallery({
    required this.photoUrls,
    this.placeName,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late int _current;
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.placeName != null
            ? Text(widget.placeName!,
                style: const TextStyle(color: Colors.white))
            : null,
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photoUrls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) {
              final tag = 'photo_${widget.placeName ?? ''}_$i';
              return Hero(
                tag: tag,
                child: InteractiveViewer(
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.photoUrls[i],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.photoUrls.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _DotsIndicator(
                count: widget.photoUrls.length,
                current: _current,
                activeColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;
  final Color activeColor;

  const _DotsIndicator({
    required this.count,
    required this.current,
    this.activeColor = _brandBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 10 : 7,
          height: active ? 10 : 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? activeColor : _dotInactive,
          ),
        );
      }),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;

  const _ShimmerBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        color: Colors.white,
      ),
    );
  }
}
