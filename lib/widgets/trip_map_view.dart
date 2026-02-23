import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

/// Day colors — vibrant, distinct
const dayColors = <Color>[
  Color(0xFF2563EB), // Day 1 blue
  Color(0xFFE91E8C), // Day 2 hot pink
  Color(0xFF16A34A), // Day 3 green
  Color(0xFFF59E0B), // Day 4 amber
  Color(0xFF7C3AED), // Day 5 purple
  Color(0xFFEF4444), // Day 6 red
  Color(0xFF0891B2), // Day 7 teal
  Color(0xFFDB2777), // Day 8 fuchsia
];

const _googleMapsKey = 'AIzaSyDvA2wmeqKw93M4v8b2Xm1uFWtIcCs46l0';

/// Decode Google encoded polyline
List<LatLng> _decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    points.add(LatLng(lat / 1E5, lng / 1E5));
  }
  return points;
}

class TripMapView extends StatefulWidget {
  final List<MapActivity> activities;
  final int selectedDayIndex; // -1 = all days
  const TripMapView({
    super.key,
    required this.activities,
    this.selectedDayIndex = -1,
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView>
    with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  final Map<String, BitmapDescriptor> _iconCache = {};
  Set<Marker> _markers = {};
  MapActivity? _selected;

  // Directions cache: "lat1,lng1->lat2,lng2" => List<LatLng>
  static final Map<String, List<LatLng>> _directionsCache = {};
  Set<Polyline> _routePolylines = {};

  // Info card animation
  late AnimationController _cardAnimController;
  late Animation<double> _cardSlideAnim;
  late Animation<double> _cardFadeAnim;

  // Pin stagger animation
  late AnimationController _pinStaggerController;
  final Map<int, Animation<double>> _pinAnims = {};

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _cardSlideAnim = Tween<double>(begin: 120, end: 0).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutCubic),
    );
    _cardFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOut),
    );

    _pinStaggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _buildMarkers();
    _fetchDirections();
  }

  @override
  void didUpdateWidget(covariant TripMapView old) {
    super.didUpdateWidget(old);
    if (old.activities != widget.activities ||
        old.selectedDayIndex != widget.selectedDayIndex) {
      _selected = null;
      _cardAnimController.reset();
      _buildMarkers();
      _fetchDirections();
      _fitBounds();
      // Restart pin stagger
      _pinStaggerController.reset();
      _pinStaggerController.forward();
    }
  }

  List<MapActivity> get _filteredActivities {
    if (widget.selectedDayIndex < 0) return widget.activities;
    return widget.activities
        .where((a) => a.dayIndex == widget.selectedDayIndex)
        .toList();
  }

  Future<void> _fitBounds() async {
    if (!_controller.isCompleted) return;
    final controller = await _controller.future;
    final acts = _filteredActivities;
    if (acts.isEmpty) return;
    if (acts.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(acts.first.lat, acts.first.lng), 15));
      return;
    }
    double minLat = acts.first.lat,
        maxLat = acts.first.lat,
        minLng = acts.first.lng,
        maxLng = acts.first.lng;
    for (final a in acts) {
      if (a.lat < minLat) minLat = a.lat;
      if (a.lat > maxLat) maxLat = a.lat;
      if (a.lng < minLng) minLng = a.lng;
      if (a.lng > maxLng) maxLng = a.lng;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<void> _buildMarkers() async {
    final acts = _filteredActivities;
    final markers = <Marker>{};

    // Setup pin stagger animations
    _pinAnims.clear();
    for (var i = 0; i < acts.length; i++) {
      final start = (i / acts.length.clamp(1, 100)) * 0.6;
      final end = (start + 0.4).clamp(0.0, 1.0);
      _pinAnims[i] = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _pinStaggerController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    }
    _pinStaggerController.reset();
    _pinStaggerController.forward();

    for (var i = 0; i < acts.length; i++) {
      final a = acts[i];
      final color = dayColors[a.dayIndex % dayColors.length];
      final cacheKey = '${a.dayIndex}_${a.numberInDay}';

      if (!_iconCache.containsKey(cacheKey)) {
        _iconCache[cacheKey] =
            await _createPin(a.numberInDay.toString(), color);
      }

      markers.add(Marker(
        markerId: MarkerId('activity_${a.dayIndex}_${a.numberInDay}'),
        position: LatLng(a.lat, a.lng),
        icon: _iconCache[cacheKey]!,
        anchor: const Offset(0.5, 1.0),
        onTap: () {
          setState(() {
            if (_selected == a) {
              _selected = null;
              _cardAnimController.reverse();
            } else {
              _selected = a;
              _cardAnimController.forward(from: 0);
            }
          });
        },
      ));
    }
    if (mounted) setState(() => _markers = markers);
  }

  /// Fetch Google Directions for consecutive activities per day
  Future<void> _fetchDirections() async {
    final acts = _filteredActivities;
    final byDay = <int, List<MapActivity>>{};
    for (final a in acts) {
      byDay.putIfAbsent(a.dayIndex, () => []).add(a);
    }

    final polylines = <Polyline>{};

    for (final entry in byDay.entries) {
      final dayActs = entry.value;
      if (dayActs.length < 2) continue;
      final color = dayColors[entry.key % dayColors.length];

      for (var i = 0; i < dayActs.length - 1; i++) {
        final from = dayActs[i];
        final to = dayActs[i + 1];
        final cacheKey =
            '${from.lat},${from.lng}->${to.lat},${to.lng}';

        List<LatLng> routePoints;
        if (_directionsCache.containsKey(cacheKey)) {
          routePoints = _directionsCache[cacheKey]!;
        } else {
          routePoints = await _fetchRoute(from.lat, from.lng, to.lat, to.lng);
          _directionsCache[cacheKey] = routePoints;
        }

        if (routePoints.isEmpty) {
          // Fallback: straight line
          routePoints = [
            LatLng(from.lat, from.lng),
            LatLng(to.lat, to.lng),
          ];
        }

        polylines.add(Polyline(
          polylineId: PolylineId('route_${entry.key}_$i'),
          points: routePoints,
          color: color.withValues(alpha: 0.4),
          width: 3,
          patterns: routePoints.length <= 2
              ? [PatternItem.dash(8), PatternItem.gap(6)]
              : [], // solid for real routes, dashed for fallback straight lines
        ));
      }
    }

    if (mounted) setState(() => _routePolylines = polylines);
  }

  Future<List<LatLng>> _fetchRoute(
      double lat1, double lng1, double lat2, double lng2) async {
    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$lat1,$lng1&destination=$lat2,$lng2&key=$_googleMapsKey');
      final resp = await http.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(resp.body);
      final routes = data['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final encoded =
            routes[0]['overview_polyline']?['points'] as String?;
        if (encoded != null && encoded.isNotEmpty) {
          debugPrint('Directions OK: ${encoded.length} chars');
          return _decodePolyline(encoded);
        }
      }
    } catch (e) {
      debugPrint('Directions API error: $e');
    }
    return [];
  }

  /// Small teardrop pin — Google Maps style, colored, with white number
  Future<BitmapDescriptor> _createPin(String label, Color color) async {
    const w = 64.0;
    const h = 88.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final cx = w / 2;

    // Shadow
    canvas.drawPath(
      _pinPath(cx, w, h, 2),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // White border
    canvas.drawPath(_pinPath(cx, w, h, 0), Paint()..color = Colors.white);

    // Colored fill
    canvas.drawPath(_pinPath(cx, w, h, 3), Paint()..color = color);

    // Number text
    final fontSize = label.length > 1 ? 22.0 : 26.0;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Position number in upper circle area of teardrop
    tp.paint(canvas, Offset(cx - tp.width / 2, h * 0.27 - tp.height / 2));

    final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),
        width: 24, height: 33);
  }

  /// Google Maps-style pin path: circle top + pointed bottom
  Path _pinPath(double cx, double w, double h, double inset) {
    final r = (w - inset * 2) / 2;
    final cy = r + inset; // center of circle
    final tipY = h - inset;
    return Path()
      ..addArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.14 * 0.15, // start angle (just past top-left)
        3.14 * 1.7,  // sweep most of circle
      )
      ..lineTo(cx, tipY) // point to bottom tip
      ..close();
  }

  LatLng get _center {
    final acts = _filteredActivities;
    if (acts.isEmpty) return const LatLng(13.7563, 100.5018);
    final lat = acts.map((a) => a.lat).reduce((a, b) => a + b) / acts.length;
    final lng = acts.map((a) => a.lng).reduce((a, b) => a + b) / acts.length;
    return LatLng(lat, lng);
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    _pinStaggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: _center, zoom: 13),
        markers: _markers,
        polylines: _routePolylines,
        onMapCreated: (c) {
          if (!_controller.isCompleted) _controller.complete(c);
          // Fit bounds after map created
          Future.delayed(const Duration(milliseconds: 400), _fitBounds);
        },
        onTap: (_) {
          if (_selected != null) {
            setState(() => _selected = null);
            _cardAnimController.reverse();
          }
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        mapType: MapType.normal,
      ),
      // Fit all places button
      Positioned(
        bottom: _selected != null ? 160 : 16,
        left: 0,
        right: 0,
        child: Center(
          child: GestureDetector(
            onTap: _fitBounds,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.zoom_out_map,
                    size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text('Fit all places',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700)),
              ]),
            ),
          ),
        ),
      ),
      // Info card with slide-up animation
      if (_selected != null)
        AnimatedBuilder(
          animation: _cardAnimController,
          builder: (context, child) => Positioned(
            bottom: 24 + _cardSlideAnim.value,
            left: 16,
            right: 16,
            child: Opacity(
              opacity: _cardFadeAnim.value,
              child: _buildInfoCard(_selected!),
            ),
          ),
        ),
    ]);
  }

  Widget _buildInfoCard(MapActivity a) {
    final color = dayColors[a.dayIndex % dayColors.length];
    return Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black54,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day badge + name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name with day-colored number badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${a.numberInDay}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                a.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Category + rating + time
                        Row(children: [
                          if (a.category != null &&
                              a.category!.isNotEmpty) ...[
                            Icon(Icons.place,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Text(
                              a.category!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (a.rating != null) ...[
                            const Icon(Icons.star,
                                size: 12, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 2),
                            Text('${a.rating}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                          ],
                          if (a.time.isNotEmpty) ...[
                            Icon(Icons.schedule,
                                size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Text(a.time,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400)),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  // Photo thumbnail (right side)
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: a.imageUrl != null && a.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: a.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: color.withValues(alpha: 0.2),
                                child: Icon(Icons.place,
                                    color: color, size: 24),
                              ),
                            )
                          : Container(
                              color: color.withValues(alpha: 0.15),
                              child:
                                  Icon(Icons.place, color: color, size: 24),
                            ),
                    ),
                  ),
                  // Close button
                  GestureDetector(
                    onTap: () {
                      setState(() => _selected = null);
                      _cardAnimController.reverse();
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child:
                          Icon(Icons.close, size: 16, color: Colors.white38),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom row: cost + actions
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(children: [
                if (a.cost != null &&
                    a.cost!.isNotEmpty &&
                    a.cost != 'Free')
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(a.cost!,
                        style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                const Spacer(),
                Text('Day ${a.dayIndex + 1}',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
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
