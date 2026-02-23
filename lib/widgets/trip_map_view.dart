import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

/// Day colors — matches Wanderlog palette (vibrant, saturated)
const dayColors = <Color>[
  Color(0xFF4285F4), // Day 1 — Google blue
  Color(0xFFEA4335), // Day 2 — Google red
  Color(0xFF34A853), // Day 3 — Google green
  Color(0xFFF4B400), // Day 4 — Google yellow/amber
  Color(0xFF9334E6), // Day 5 — Purple
  Color(0xFFE91E63), // Day 6 — Pink
  Color(0xFF00ACC1), // Day 7 — Cyan
  Color(0xFFFF6D00), // Day 8 — Deep orange
];

const _mapsKey = 'AIzaSyDvA2wmeqKw93M4v8b2Xm1uFWtIcCs46l0';

// ─── Polyline decoder ────────────────────────────────────────
List<LatLng> _decodePolyline(String encoded) {
  final pts = <LatLng>[];
  int i = 0, lat = 0, lng = 0;
  while (i < encoded.length) {
    for (var coord = 0; coord < 2; coord++) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(i++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      if (coord == 0) lat += delta; else lng += delta;
    }
    pts.add(LatLng(lat / 1E5, lng / 1E5));
  }
  return pts;
}

// ─── Widget ──────────────────────────────────────────────────
class TripMapView extends StatefulWidget {
  final List<MapActivity> activities;
  final int selectedDayIndex;
  const TripMapView({
    super.key,
    required this.activities,
    this.selectedDayIndex = -1,
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  final Map<String, BitmapDescriptor> _iconCache = {};
  static final Map<String, List<LatLng>> _routeCache = {};

  static const _mapStyle = '''
[
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#e0f0ff"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e0e0e0"}]},
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e8f5e9"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#c0c0c0"}]},
  {"featureType":"road","elementType":"labels","stylers":[{"visibility":"simplified"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.neighborhood","stylers":[{"visibility":"off"}]}
]
''';

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  MapActivity? _selected;

  late final AnimationController _cardAnim;

  @override
  void initState() {
    super.initState();
    _cardAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _rebuild();
  }

  @override
  void didUpdateWidget(covariant TripMapView old) {
    super.didUpdateWidget(old);
    if (old.activities != widget.activities ||
        old.selectedDayIndex != widget.selectedDayIndex) {
      _selected = null;
      _cardAnim.reset();
      _rebuild();
      _fitBounds();
    }
  }

  @override
  void dispose() {
    _cardAnim.dispose();
    super.dispose();
  }

  List<MapActivity> get _visible {
    if (widget.selectedDayIndex < 0) return widget.activities;
    return widget.activities
        .where((a) => a.dayIndex == widget.selectedDayIndex)
        .toList();
  }

  // ─── Markers ─────────────────────────────────────────────
  Future<void> _rebuild() async {
    final acts = _visible;
    final m = <Marker>{};
    for (var i = 0; i < acts.length; i++) {
      final a = acts[i];
      final c = dayColors[a.dayIndex % dayColors.length];
      final key = '${c.value}_${a.numberInDay}';
      _iconCache[key] ??= await _makeIcon(a.numberInDay, c);
      m.add(Marker(
        markerId: MarkerId('${a.dayIndex}_${a.numberInDay}'),
        position: LatLng(a.lat, a.lng),
        icon: _iconCache[key]!,
        anchor: const Offset(0.5, 1.0),
        zIndex: acts.length - i.toDouble(),
        onTap: () {
          _selectPin(a);
        },
      ));
    }
    if (mounted) setState(() => _markers = m);
  }

  void _selectPin(MapActivity a) async {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected == a) {
        _selected = null;
        _cardAnim.reverse();
      } else {
        _selected = a;
        _cardAnim.forward(from: 0);
      }
    });
    if (_selected != null && _mapCtrl.isCompleted) {
      final ctrl = await _mapCtrl.future;
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(a.lat, a.lng), 14,
      ));
    }
  }

  // ─── Pin icon: exact Google Maps marker shape ────────────
  Future<BitmapDescriptor> _makeIcon(int number, Color color) async {
    // High-res canvas → scaled down for crisp retina rendering
    const s = 96.0; // canvas width
    const h = 128.0; // canvas height
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final cx = s / 2;
    final circleR = s * 0.42;
    final circleY = circleR + 4;
    final tipY = h - 4;

    // Build Google-style marker path
    final path = Path();
    // Arc: full circle minus bottom wedge
    final wedgeAngle = math.atan2(cx, tipY - circleY) * 0.7;
    final startAngle = math.pi / 2 + wedgeAngle;
    final sweepAngle = 2 * math.pi - 2 * wedgeAngle;
    path.arcTo(
      Rect.fromCircle(center: Offset(cx, circleY), radius: circleR),
      startAngle,
      sweepAngle,
      false,
    );
    path.lineTo(cx, tipY);
    path.close();

    // Shadow
    c.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // White stroke
    c.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Fill
    c.drawPath(path, Paint()..color = color);

    // Number (white, bold, centered in circle)
    final label = '$number';
    final fs = label.length > 1 ? 36.0 : 42.0;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
            color: Colors.white, fontSize: fs, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, circleY - tp.height / 2));

    final img = await rec.endRecording().toImage(s.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    // Display at 28×37 logical px (crisp on retina)
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),
        width: 36, height: 48);
  }

  // ─── Routes (Directions API) ─────────────────────────────
  Future<void> _fetchRoutes() async {
    final acts = _visible;
    final byDay = <int, List<MapActivity>>{};
    for (final a in acts) {
      byDay.putIfAbsent(a.dayIndex, () => []).add(a);
    }

    final poly = <Polyline>{};
    for (final e in byDay.entries) {
      final day = e.value;
      if (day.length < 2) continue;
      final color = dayColors[e.key % dayColors.length];

      // Build waypoints for multi-stop route (single API call per day)
      final origin = '${day.first.lat},${day.first.lng}';
      final dest = '${day.last.lat},${day.last.lng}';
      final waypoints = day.length > 2
          ? day
              .sublist(1, day.length - 1)
              .map((a) => '${a.lat},${a.lng}')
              .join('|')
          : null;

      final cacheKey = '$origin->$dest|$waypoints';
      List<LatLng>? route = _routeCache[cacheKey];

      if (route == null) {
        route = await _fetchDayRoute(origin, dest, waypoints);
        _routeCache[cacheKey] = route;
      }

      if (route.isEmpty) {
        // Fallback: straight lines
        route = day.map((a) => LatLng(a.lat, a.lng)).toList();
      }

      poly.add(Polyline(
        polylineId: PolylineId('day_${e.key}'),
        points: route,
        color: color.withValues(alpha: 0.7),
        width: 4,
        patterns: route.length <= day.length
            ? [PatternItem.dash(10), PatternItem.gap(8)]
            : [],
      ));
    }

    if (mounted) setState(() => _polylines = poly);
  }

  Future<List<LatLng>> _fetchDayRoute(
      String origin, String dest, String? waypoints) async {
    try {
      var url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$origin&destination=$dest&key=$_mapsKey';
      if (waypoints != null) url += '&waypoints=$waypoints';
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      final data = jsonDecode(resp.body);
      if (data['status'] == 'OK') {
        // Combine all legs
        final legs = data['routes'][0]['legs'] as List;
        final allPts = <LatLng>[];
        for (final leg in legs) {
          final steps = leg['steps'] as List;
          for (final step in steps) {
            final enc = step['polyline']['points'] as String;
            allPts.addAll(_decodePolyline(enc));
          }
        }
        debugPrint('Route OK: ${allPts.length} points');
        return allPts;
      }
      debugPrint('Directions status: ${data['status']}');
    } catch (e) {
      debugPrint('Directions error: $e');
    }
    return [];
  }

  // ─── Camera ──────────────────────────────────────────────
  Future<void> _fitBounds() async {
    if (!_mapCtrl.isCompleted) return;
    final ctrl = await _mapCtrl.future;
    final acts = _visible;
    if (acts.isEmpty) return;
    if (acts.length == 1) {
      ctrl.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(acts[0].lat, acts[0].lng), 15));
      return;
    }
    var minLat = acts[0].lat, maxLat = acts[0].lat;
    var minLng = acts[0].lng, maxLng = acts[0].lng;
    for (final a in acts) {
      if (a.lat < minLat) minLat = a.lat;
      if (a.lat > maxLat) maxLat = a.lat;
      if (a.lng < minLng) minLng = a.lng;
      if (a.lng > maxLng) maxLng = a.lng;
    }
    ctrl.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng)),
      72,
    ));
  }

  LatLng get _center {
    final a = _visible;
    if (a.isEmpty) return const LatLng(13.7563, 100.5018);
    return LatLng(
      a.map((x) => x.lat).reduce((a, b) => a + b) / a.length,
      a.map((x) => x.lng).reduce((a, b) => a + b) / a.length,
    );
  }

  // ─── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Map
      GoogleMap(
        initialCameraPosition: CameraPosition(target: _center, zoom: 12),
        markers: _markers,
        polylines: const {},
        onMapCreated: (c) {
          c.setMapStyle(_mapStyle);
          if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
          Future.delayed(const Duration(milliseconds: 500), _fitBounds);
        },
        onTap: (_) {
          if (_selected != null) {
            setState(() => _selected = null);
            _cardAnim.reverse();
          }
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),

      // ── Fit all places pill ──
      Positioned(
        bottom: _selected != null ? 170 : 20,
        left: 0,
        right: 0,
        child: Center(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _fitBounds();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.zoom_out_map, size: 16, color: Color(0xFF5F6368)),
                SizedBox(width: 6),
                Text('Fit all places',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5F6368))),
              ]),
            ),
          ),
        ),
      ),

      // ── Info card ──
      if (_selected != null)
        AnimatedBuilder(
          animation: _cardAnim,
          builder: (_, __) {
            final slide = Tween<double>(begin: 80, end: 0)
                .animate(CurvedAnimation(
                    parent: _cardAnim, curve: Curves.easeOutBack))
                .value;
            final opacity = _cardAnim.value.clamp(0.0, 1.0);
            return Positioned(
              bottom: 24 + slide,
              left: 16,
              right: 16,
              child: Opacity(
                opacity: opacity,
                child: _infoCard(_selected!),
              ),
            );
          },
        ),
    ]);
  }

  // ─── Dark info card (Wanderlog-style) ────────────────────
  Widget _infoCard(MapActivity a) {
    final color = dayColors[a.dayIndex % dayColors.length];
    return GestureDetector(
      onTap: () {}, // absorb taps
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF202030),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Colored number badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${a.numberInDay}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              // Name + meta
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      // Meta row
                      DefaultTextStyle(
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade400),
                        child: Row(children: [
                          if (a.category != null && a.category!.isNotEmpty) ...[
                            Text(a.category!),
                            _dot(),
                          ],
                          if (a.rating != null) ...[
                            const Icon(Icons.star,
                                size: 12, color: Color(0xFFFBBC04)),
                            Text(' ${a.rating}'),
                            _dot(),
                          ],
                          if (a.time.isNotEmpty) Text(a.time),
                        ]),
                      ),
                    ]),
              ),
              // Photo
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: a.imageUrl != null && a.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: a.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _photoPlaceholder(color),
                        )
                      : _photoPlaceholder(color),
                ),
              ),
              // Close
              GestureDetector(
                onTap: () {
                  setState(() => _selected = null);
                  _cardAnim.reverse();
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 40),
                  child: Icon(Icons.close, size: 18, color: Colors.white30),
                ),
              ),
            ]),
          ),
          // Bottom actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(children: [
              if (a.cost != null && a.cost!.isNotEmpty && a.cost != 'Free')
                _chip(a.cost!, const Color(0xFF34A853)),
              const Spacer(),
              Text('Day ${a.dayIndex + 1}',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _dot() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text('·',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14)));

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: TextStyle(
                color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _photoPlaceholder(Color c) => Container(
      color: c.withValues(alpha: 0.15),
      child: Icon(Icons.place, color: c, size: 22));
}

// ─── Model ─────────────────────────────────────────────────
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
