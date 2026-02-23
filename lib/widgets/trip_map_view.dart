import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Day colors — vibrant, distinct
const _dayColors = <Color>[
  Color(0xFF2563EB), // Day 1 blue
  Color(0xFFE91E8C), // Day 2 hot pink
  Color(0xFF16A34A), // Day 3 green
  Color(0xFFF59E0B), // Day 4 amber
  Color(0xFF7C3AED), // Day 5 purple
  Color(0xFFEF4444), // Day 6 red
  Color(0xFF0891B2), // Day 7 teal
  Color(0xFFDB2777), // Day 8 fuchsia
];

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
      final cacheKey = '${a.dayIndex}_${a.numberInDay}';

      if (!_iconCache.containsKey(cacheKey)) {
        _iconCache[cacheKey] =
            await _createPin(a.numberInDay.toString(), color);
      }

      markers.add(Marker(
        markerId: MarkerId('activity_$i'),
        position: LatLng(a.lat, a.lng),
        icon: _iconCache[cacheKey]!,
        anchor: const Offset(0.5, 1.0),
        onTap: () => setState(() => _selected = _selected == a ? null : a),
      ));
    }
    if (mounted) setState(() => _markers = markers);
  }

  /// Large teardrop pin — 160px canvas for crisp rendering
  Future<BitmapDescriptor> _createPin(String label, Color color) async {
    const w = 120.0;
    const h = 160.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final cx = w / 2;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final shadowPath = Path()
      ..moveTo(cx, h - 2)
      ..cubicTo(cx - 18, h - 30, 6, h * 0.45, 6, h * 0.33)
      ..arcToPoint(Offset(w - 6, h * 0.33),
          radius: Radius.circular((w - 12) / 2), clockwise: false)
      ..cubicTo(w - 6, h * 0.45, cx + 18, h - 30, cx, h - 2)
      ..close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Main teardrop
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(cx, h - 8)
      ..cubicTo(cx - 16, h - 34, 8, h * 0.44, 8, h * 0.32)
      ..arcToPoint(Offset(w - 8, h * 0.32),
          radius: Radius.circular((w - 16) / 2), clockwise: false)
      ..cubicTo(w - 8, h * 0.44, cx + 16, h - 34, cx, h - 8)
      ..close();
    canvas.drawPath(path, paint);

    // White circle
    const circleR = 26.0;
    const circleY = 48.0;
    canvas.drawCircle(
        Offset(cx, circleY), circleR, Paint()..color = Colors.white);

    // Number
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: label.length > 1 ? 26 : 30,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, circleY - tp.height / 2));

    final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),
        width: 48, height: 64);
  }

  Set<Polyline> get _polylines {
    // Per-day polylines with day color
    final byDay = <int, List<LatLng>>{};
    for (final a in widget.activities) {
      byDay.putIfAbsent(a.dayIndex, () => []).add(LatLng(a.lat, a.lng));
    }
    return byDay.entries
        .where((e) => e.value.length >= 2)
        .map((e) => Polyline(
              polylineId: PolylineId('day_${e.key}'),
              points: e.value,
              color:
                  _dayColors[e.key % _dayColors.length].withValues(alpha: 0.6),
              width: 3,
              patterns: [PatternItem.dash(12), PatternItem.gap(8)],
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
        initialCameraPosition: CameraPosition(target: _center, zoom: 13),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (c) => _controller.complete(c),
        onTap: (_) => setState(() => _selected = null),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),
      // Day legend
      Positioned(
        top: 12,
        left: 12,
        child: _dayLegend(),
      ),
      // Info card
      if (_selected != null) _buildInfoCard(_selected!),
    ]);
  }

  Widget _dayLegend() {
    final dayCount =
        widget.activities.map((a) => a.dayIndex).toSet().toList()..sort();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: dayCount.map((d) {
          final c = _dayColors[d % _dayColors.length];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text('Day ${d + 1}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoCard(MapActivity a) {
    final color = _dayColors[a.dayIndex % _dayColors.length];
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black26,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            // Photo
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 110,
                height: 110,
                child: a.imageUrl != null && a.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: a.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: color.withValues(alpha: 0.1),
                          child: Icon(Icons.place, color: color, size: 32),
                        ),
                      )
                    : Container(
                        color: color.withValues(alpha: 0.08),
                        child: Icon(Icons.place, color: color, size: 32),
                      ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Day + Category badges
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('DAY ${a.dayIndex + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                      if (a.category != null && a.category!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            a.category!.substring(0, 1).toUpperCase() +
                                a.category!.substring(1),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    // Name
                    Text(a.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    // Rating + time
                    Row(children: [
                      if (a.rating != null) ...[
                        const Icon(Icons.star,
                            size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text('${a.rating}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                      ],
                      if (a.time.isNotEmpty) ...[
                        Icon(Icons.schedule,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(a.time,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ]),
                    // Cost
                    if (a.cost != null &&
                        a.cost!.isNotEmpty &&
                        a.cost != 'Free') ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(a.cost!,
                            style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Close
            GestureDetector(
              onTap: () => setState(() => _selected = null),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

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
