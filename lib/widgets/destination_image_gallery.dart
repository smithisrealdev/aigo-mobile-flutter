import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../models/models.dart';
import '../services/image_service.dart';

/// Grid gallery for destination images with full-screen tap.
class DestinationImageGallery extends ConsumerWidget {
  final String destinationName;
  final int crossAxisCount;
  final double spacing;

  const DestinationImageGallery({
    super.key,
    required this.destinationName,
    this.crossAxisCount = 2,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(destinationImagesProvider(destinationName));

    return imagesAsync.when(
      loading: () => _buildShimmerGrid(),
      error: (e, _) => Center(
        child: Text('Failed to load images',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ),
      data: (images) {
        if (images.isEmpty) return const SizedBox.shrink();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: images.length,
          itemBuilder: (context, i) => _ImageTile(
            image: images[i],
            allImages: images,
            index: i,
          ),
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final DestinationImage image;
  final List<DestinationImage> allImages;
  final int index;

  const _ImageTile({
    required this.image,
    required this.allImages,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: image.imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(color: Colors.white),
          ),
          errorWidget: (_, _, _) => Container(
            color: const Color(0xFFE6E6E6),
            child: const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenViewer(
          images: allImages,
          initialIndex: index,
        ),
      ),
    );
  }
}

class _FullScreenViewer extends StatefulWidget {
  final List<DestinationImage> images;
  final int initialIndex;

  const _FullScreenViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
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
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        itemBuilder: (context, i) {
          return InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.images[i].imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
