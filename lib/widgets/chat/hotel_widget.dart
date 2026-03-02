import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/chat/widget_models.dart';
import '../../theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HotelWidget extends StatefulWidget {
  final List<HotelInfo> hotels;
  final bool isDark;

  const HotelWidget({super.key, required this.hotels, this.isDark = false});

  @override
  State<HotelWidget> createState() => _HotelWidgetState();
}

class _HotelWidgetState extends State<HotelWidget> {
  // Simple cache for resolved images
  final Map<String, String> _resolvedImages = {};

  @override
  void initState() {
    super.initState();
    _resolveImages();
  }

  Future<void> _resolveImages() async {
    for (final hotel in widget.hotels) {
      if (hotel.imageUrl != null) continue; // Already have image, or real data

      final placeholder = 'IMAGE:${hotel.name} ${hotel.area} hotel exterior';
      final supabase = Supabase.instance.client;
      try {
        final res = await supabase.functions.invoke(
          'google-search',
          body: {'query': placeholder},
        );
        if (mounted && res.data != null && res.data['imageUrl'] != null) {
          setState(() {
            _resolvedImages[hotel.name] = res.data['imageUrl'];
          });
        }
      } catch (e) {
        debugPrint('Failed to resolve hotel image: \$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hotels.isEmpty) return const SizedBox.shrink();

    final bgColor = widget.isDark
        ? const Color(0xFF78350F).withValues(alpha: 0.2)
        : const Color(0xFFFFFBEB);
    final borderColor = widget.isDark
        ? const Color(0xFF92400E).withValues(alpha: 0.5)
        : const Color(0xFFFDE68A);
    final primaryTextColor = widget.isDark
        ? Colors.white
        : AppColors.textPrimary;
    final secondaryTextColor = widget.isDark
        ? Colors.white70
        : AppColors.textSecondary;
    final headerTextColor = widget.isDark
        ? const Color(0xFFFCD34D)
        : const Color(0xFFB45309);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hotel, size: 16, color: Colors.amber.shade500),
              const SizedBox(width: 6),
              const Text(
                'HOTEL OPTIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.hotels.map(
            (hotel) => _buildHotelCard(
              hotel,
              bgColor,
              borderColor,
              headerTextColor,
              primaryTextColor,
              secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelCard(
    HotelInfo hotel,
    Color bgColor,
    Color borderColor,
    Color headerTextColor,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final starsNum = double.tryParse(hotel.rating) ?? 0.0;
    final int stars = starsNum.round();

    final imgUrl = hotel.imageUrl ?? _resolvedImages[hotel.name];

    final bookingUrl =
        hotel.bookingUrl ??
        'https://www.booking.com/searchresults.html?ss=\${Uri.encodeComponent("\${hotel.name} \${hotel.area}")}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imgUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imgUrl,
                width: double.infinity,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(hotel.name),
              ),
            )
          else
            _buildPlaceholder(hotel.name),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hotel, size: 14, color: headerTextColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hotel.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (hotel.area.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                hotel.area,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: secondaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hotel.price,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: headerTextColor,
                    ),
                  ),
                  Text(
                    '/night',
                    style: TextStyle(fontSize: 10, color: secondaryTextColor),
                  ),
                ],
              ),
            ],
          ),
          if (stars > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  ...List.generate(
                    5,
                    (index) => Icon(
                      Icons.star,
                      size: 14,
                      color: index < stars
                          ? Colors.amber.shade400
                          : Colors.grey.shade300,
                    ),
                  ),
                  if (hotel.rating.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      hotel.rating,
                      style: TextStyle(fontSize: 11, color: secondaryTextColor),
                    ),
                  ],
                ],
              ),
            ),
          if (hotel.highlights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: hotel.highlights
                    .take(4)
                    .map(
                      (h) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: headerTextColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getHighlightIcon(h),
                              size: 10,
                              color: headerTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              h,
                              style: TextStyle(
                                fontSize: 10,
                                color: headerTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, size: 12, color: secondaryTextColor),
                  const SizedBox(width: 4),
                  Text(
                    'Estimated price',
                    style: TextStyle(fontSize: 10, color: secondaryTextColor),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(bookingUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'View & Book',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.open_in_new, size: 12, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String name) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade200.withValues(alpha: widget.isDark ? 0.3 : 1),
            Colors.orange.shade200.withValues(alpha: widget.isDark ? 0.3 : 1),
            Colors.red.shade200.withValues(alpha: widget.isDark ? 0.3 : 1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'H',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.amber.shade700.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  IconData _getHighlightIcon(String highlight) {
    final lower = highlight.toLowerCase();
    if (lower.contains('wifi')) return Icons.wifi;
    if (lower.contains('breakfast')) return Icons.coffee;
    if (lower.contains('parking')) return Icons.directions_car;
    if (lower.contains('pool')) return Icons.pool;
    if (lower.contains('spa')) return Icons.spa;
    return Icons.star;
  }
}
