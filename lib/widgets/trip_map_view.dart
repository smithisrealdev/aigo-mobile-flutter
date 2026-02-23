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
        infoWindow: InfoWindow(title: a.name, snippet: a.time),
        icon: _iconCache[cacheKey]!,
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
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _center, zoom: 12),
      markers: _markers,
      polylines: _polylines,
      onMapCreated: (c) => _controller.complete(c),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
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

  const MapActivity({
    required this.name,
    required this.time,
    required this.lat,
    required this.lng,
    this.dayIndex = 0,
    this.numberInDay = 1,
  });
}
