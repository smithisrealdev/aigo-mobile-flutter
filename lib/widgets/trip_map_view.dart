import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Day colors matching itinerary_screen._numberColors
const _dayColors = <Color>[
  Color(0xFF2563EB), // Day 1 blue
  Color(0xFFEC4899), // Day 2 pink
  Color(0xFF10B981), // Day 3 green
  Color(0xFFF59E0B), // Day 4 amber
  Color(0xFF8B5CF6), // Day 5 purple
  Color(0xFFEF4444), // Day 6 red
  Color(0xFF06B6D4), // Day 7 cyan
  Color(0xFF6366F1), // Day 8 indigo
];

/// Full-screen Google Map showing trip activities as colored numbered markers.
class TripMapView extends StatefulWidget {
  final List<MapActivity> activities;

  const TripMapView({super.key, required this.activities});

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  final Completer<GoogleMapController> _controller = Completer();
  final Map<String, BitmapDescriptor> _iconCache = {};
  Set<Marker> _markers = {};
  MapActivity? _selected;

  @override
  void initState() {
    super.initState();
    _buildMarkers();
  }

  @override
  void didUpdateWidget(covariant TripMapView old) {
    super.didUpdateWidget(old);
    if (old.activities != widget.activities) _buildMarkers();
  }

  Future<void> _buildMarkers() async {
    final markers = <Marker>{};
    for (var i = 0; i < widget.activities.length; i++) {
      final a = widget.activities[i];
      final color = _dayColors[a.dayIndex % _dayColors.length];
      final label = '${a.numberInDay}';
      final cacheKey = '${a.dayIndex}_$label';

      if (!_iconCache.containsKey(cacheKey)) {
        _iconCache[cacheKey] = await _createNumberedIcon(label, color);
      }

      markers.add(Marker(
        markerId: MarkerId('activity_$i'),
        position: LatLng(a.lat, a.lng),
        icon: _iconCache[cacheKey]!,
        onTap: () => setState(() => _selected = _selected == a ? null : a),
      ));
    }
    if (mounted) setState(() => _markers = markers);
  }

  /// Draw a colored teardrop pin with a white number inside.
  Future<BitmapDescriptor> _createNumberedIcon(
      String label, Color color) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Teardrop shape
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size / 2, size * 0.92)
      ..cubicTo(size * 0.35, size * 0.7, 0, size * 0.45, 0, size * 0.32)
      ..arcToPoint(Offset(size, size * 0.32),
          radius: Radius.circular(size / 2), clockwise: false)
      ..cubicTo(
          size, size * 0.45, size * 0.65, size * 0.7, size / 2, size * 0.92)
      ..close();
    canvas.drawPath(path, paint);

    // White circle inside
    canvas.drawCircle(
        Offset(size / 2, size * 0.32), size * 0.22, Paint()..color = Colors.white);

    // Number text
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
            color: color,
            fontSize: size * 0.26,
            fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas,
        Offset(
            size / 2 - tp.width / 2, size * 0.32 - tp.height / 2));

    final image = await recorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),
        width: 40, height: 40);
  }

  Set<Polyline> get _polylines {
    if (widget.activities.length < 2) return {};
    // Group by day and draw polylines per day
    final byDay = <int, List<LatLng>>{};
    for (final a in widget.activities) {
      byDay.putIfAbsent(a.dayIndex, () => []).add(LatLng(a.lat, a.lng));
    }
    return byDay.entries
        .where((e) => e.value.length >= 2)
        .map((e) => Polyline(
              polylineId: PolylineId('day_${e.key}'),
              points: e.value,
              color: _dayColors[e.key % _dayColors.length],
              width: 3,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ))
        .toSet();
  }

  LatLng get _center {
    if (widget.activities.isEmpty) return const LatLng(13.7563, 100.5018);
    final lat = widget.activities.map((a) => a.lat).reduce((a, b) => a + b) /
        widget.activities.length;
    final lng = widget.activities.map((a) => a.lng).reduce((a, b) => a + b) /
        widget.activities.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: _center, zoom: 12),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (c) => _controller.complete(c),
        onTap: (_) => setState(() => _selected = null),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
      ),
      if (_selected != null) _buildInfoCard(_selected!),
    ]);
  }

  Widget _buildInfoCard(MapActivity a) {
    final color = _dayColors[a.dayIndex % _dayColors.length];
    return Positioned(
      top: 60,
      left: 20,
      right: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo + badges
              if (a.imageUrl != null && a.imageUrl!.isNotEmpty)
                Stack(children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      a.imageUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(height: 140, color: color.withValues(alpha: 0.1)),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DAY ${a.dayIndex + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (a.category != null)
                    Positioned(
                      top: 8,
                      left: 70,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(a.category!,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      ),
                    ),
                  if (a.cost != null && a.cost!.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(a.cost!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (a.rating != null) ...[
                        const Icon(Icons.star,
                            size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text('${a.rating}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                      ],
                      Icon(Icons.schedule,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        'Day ${a.dayIndex + 1} · ${a.time}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data class for map activity pins.
class MapActivity {
  final String name;
  final String time;
  final double lat;
  final double lng;
  final int dayIndex;
  final int numberInDay;
  final String? imageUrl;
  final String? category;
  final double? rating;
  final String? cost;
  final String? duration;

  const MapActivity({
    required this.name,
    required this.time,
    required this.lat,
    required this.lng,
    this.dayIndex = 0,
    this.numberInDay = 1,
    this.imageUrl,
    this.category,
    this.rating,
    this.cost,
    this.duration,
  });
}
