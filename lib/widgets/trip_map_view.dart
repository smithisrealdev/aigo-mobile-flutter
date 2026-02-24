import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Category-based marker colors (Wanderlog style)
const _categoryColors = <String, Color>{
  'restaurant': Color(0xFFEA4335), // Red
  'temple': Color(0xFF34A853),     // Green (attraction)
  'museum': Color(0xFF34A853),     // Green (attraction)
  'park': Color(0xFF34A853),       // Green (attraction)
  'attraction': Color(0xFF34A853), // Green
  'shopping': Color(0xFF4285F4),   // Blue
  'hotel': Color(0xFF9334E6),      // Purple
  'beach': Color(0xFF00ACC1),      // Teal
  'transport': Color(0xFF64748B),  // Gray
};

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

// ─── Widget ──────────────────────────────────────────────────
class TripMapView extends StatefulWidget {
  final List<MapActivity> activities;
  final int selectedDayIndex;
  final bool hideInfoCard;
  final void Function(MapActivity)? onPinTap;
  const TripMapView({
    super.key,
    required this.activities,
    this.selectedDayIndex = -1,
    this.hideInfoCard = false,
    this.onPinTap,
  });

  @override
  State<TripMapView> createState() => TripMapViewState();
}

class TripMapViewState extends State<TripMapView>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  final Map<String, BitmapDescriptor> _iconCache = {};

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
  static final Map<String, List<LatLng>> _routeCache = {};
  MapActivity? _selected;
  int _activeIndex = -1;
  double _currentZoom = 12;
  late final AnimationController _cardAnim;

  @override
  void initState() {
    super.initState();
    _cardAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _rebuild();
    _fetchRoutes();
  }

  @override
  void didUpdateWidget(covariant TripMapView old) {
    super.didUpdateWidget(old);
    if (old.activities != widget.activities ||
        old.selectedDayIndex != widget.selectedDayIndex) {
      _selected = null;
      _cardAnim.reset();
      _rebuild();
      _fetchRoutes();
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

  // ─── Clustering logic ────────────────────────────────────
  /// Groups nearby activities into clusters at low zoom levels.
  /// At zoom >= 13, show all individual pins.
  List<_MarkerItem> _clusterActivities() {
    final acts = _visible;
    if (acts.isEmpty) return [];
    if (_currentZoom >= 13 || acts.length <= 8) {
      // No clustering needed — show all pins individually
      return acts.map((a) => _MarkerItem.single(a)).toList();
    }

    // Simple grid-based clustering
    // At zoom 10, ~0.05 deg ≈ 5km grouping; scales with zoom
    final gridSize = 0.15 / math.pow(2, _currentZoom - 8);
    final clusters = <String, List<MapActivity>>{};

    for (final a in acts) {
      final gx = (a.lat / gridSize).floor();
      final gy = (a.lng / gridSize).floor();
      final key = '$gx,$gy';
      clusters.putIfAbsent(key, () => []).add(a);
    }

    return clusters.values.map((group) {
      if (group.length == 1) return _MarkerItem.single(group.first);
      // Cluster center = average of all points
      final avgLat = group.map((a) => a.lat).reduce((a, b) => a + b) / group.length;
      final avgLng = group.map((a) => a.lng).reduce((a, b) => a + b) / group.length;
      return _MarkerItem.cluster(group, avgLat, avgLng);
    }).toList();
  }

  // ─── Build markers from clusters ─────────────────────────
  Future<void> _rebuild() async {
    final items = _clusterActivities();
    final m = <Marker>{};

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.isCluster) {
        // Cluster marker
        final key = 'cluster_${item.count}';
        _iconCache[key] ??= await _makeClusterIcon(item.count);
        m.add(Marker(
          markerId: MarkerId('cluster_${item.lat}_${item.lng}'),
          position: LatLng(item.lat, item.lng),
          icon: _iconCache[key]!,
          anchor: const Offset(0.5, 0.5),
          zIndex: 1000,
          onTap: () async {
            // Zoom in to expand cluster
            if (_mapCtrl.isCompleted) {
              final ctrl = await _mapCtrl.future;
              ctrl.animateCamera(CameraUpdate.newLatLngZoom(
                  LatLng(item.lat, item.lng), _currentZoom + 2));
            }
          },
        ));
      } else {
        // Single pin
        final a = item.activity!;
        final c = _categoryColors[a.category] ?? dayColors[a.dayIndex % dayColors.length];
        final actIdx = widget.activities.indexOf(a);
        final isActive = actIdx == _activeIndex;
        final key = isActive ? 'active_${c.value}_${a.numberInDay}' : '${c.value}_${a.numberInDay}';
        _iconCache[key] ??= isActive ? await _makeActiveIcon(a.numberInDay, c) : await _makeIcon(a.numberInDay, c);
        m.add(Marker(
          markerId: MarkerId('${a.dayIndex}_${a.numberInDay}'),
          position: LatLng(a.lat, a.lng),
          icon: _iconCache[key]!,
          anchor: const Offset(0.5, 1.0),
          zIndex: isActive ? 9999 : items.length - i.toDouble(),
          onTap: () => _selectPin(a),
        ));
      }
    }
    if (mounted) setState(() => _markers = m);
  }

  /// Public API: animate camera to a specific activity from outside.
  void animateTo(MapActivity a) async {
    final idx = widget.activities.indexOf(a);
    if (idx != _activeIndex) {
      _activeIndex = idx;
      _rebuild();
    }
    if (_mapCtrl.isCompleted) {
      final ctrl = await _mapCtrl.future;
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(a.lat, a.lng), 14,
      ));
    }
  }

  /// Public API: fit bounds from outside.
  void fitBoundsPublic() => _fitBounds();

  void _selectPin(MapActivity a) async {
    HapticFeedback.selectionClick();
    if (widget.onPinTap != null) {
      widget.onPinTap!(a);
      return;
    }
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

  // ─── Cluster icon: red circle with count ─────────────────
  Future<BitmapDescriptor> _makeClusterIcon(int count) async {
    const size = 96.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final center = const Offset(size / 2, size / 2);
    const radius = size * 0.42;

    // Shadow
    c.drawCircle(center.translate(0, 2), radius + 2, Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // White border
    c.drawCircle(center, radius + 3, Paint()..color = Colors.white);
    // Red fill
    c.drawCircle(center, radius, Paint()..color = const Color(0xFFEA4335));

    // Count text
    final label = count > 99 ? '99+' : '$count';
    final fs = label.length > 2 ? 28.0 : 36.0;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: Colors.white, fontSize: fs, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 40, height: 40);
  }

  // ─── Pin icon: Google Maps teardrop shape ────────────────
  Future<BitmapDescriptor> _makeIcon(int number, Color color) async {
    const s = 96.0;
    const h = 128.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final cx = s / 2;
    final circleR = s * 0.42;
    final circleY = circleR + 4;
    final tipY = h - 4;

    final path = Path();
    final wedgeAngle = math.atan2(cx, tipY - circleY) * 0.7;
    final startAngle = math.pi / 2 + wedgeAngle;
    final sweepAngle = 2 * math.pi - 2 * wedgeAngle;
    path.arcTo(
      Rect.fromCircle(center: Offset(cx, circleY), radius: circleR),
      startAngle, sweepAngle, false,
    );
    path.lineTo(cx, tipY);
    path.close();

    c.drawPath(path.shift(const Offset(0, 3)), Paint()
      ..color = Colors.black38
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    c.drawPath(path, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5);
    c.drawPath(path, Paint()..color = color);

    final label = '$number';
    final fs = label.length > 1 ? 36.0 : 42.0;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: Colors.white, fontSize: fs, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, circleY - tp.height / 2));

    final img = await rec.endRecording().toImage(s.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 36, height: 48);
  }

  /// Active pin: 1.5x bigger with bright blue ring
  Future<BitmapDescriptor> _makeActiveIcon(int number, Color color) async {
    const s = 144.0; // 1.5x of 96
    const h = 192.0; // 1.5x of 128
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final cx = s / 2;
    final circleR = s * 0.42;
    final circleY = circleR + 6;
    final tipY = h - 6;

    final path = Path();
    final wedgeAngle = math.atan2(cx, tipY - circleY) * 0.7;
    final startAngle = math.pi / 2 + wedgeAngle;
    final sweepAngle = 2 * math.pi - 2 * wedgeAngle;
    path.arcTo(
      Rect.fromCircle(center: Offset(cx, circleY), radius: circleR),
      startAngle, sweepAngle, false,
    );
    path.lineTo(cx, tipY);
    path.close();

    // Outer glow
    c.drawPath(path.shift(const Offset(0, 4)), Paint()
      ..color = Colors.black38
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // Blue highlight ring
    c.drawPath(path, Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10);
    // White border
    c.drawPath(path, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6);
    // Fill
    c.drawPath(path, Paint()..color = color);

    final label = '$number';
    final fs = label.length > 1 ? 54.0 : 63.0;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: Colors.white, fontSize: fs, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(cx - tp.width / 2, circleY - tp.height / 2));

    final img = await rec.endRecording().toImage(s.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 54, height: 72);
  }

  // ─── Polyline decoder ──────────────────────────────────
  static List<LatLng> _decodePolyline(String encoded) {
    final pts = <LatLng>[];
    int i = 0, lat = 0, lng = 0;
    while (i < encoded.length) {
      for (var coord = 0; coord < 2; coord++) {
        int shift = 0, result = 0, b;
        do { b = encoded.codeUnitAt(i++) - 63; result |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
        final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        if (coord == 0) lat += delta; else lng += delta;
      }
      pts.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return pts;
  }

  // ─── Routes (Directions API) ─────────────────────────────
  Future<void> _fetchRoutes() async {
    final acts = _visible;
    final byDay = <int, List<MapActivity>>{};
    for (final a in acts) byDay.putIfAbsent(a.dayIndex, () => []).add(a);

    final poly = <Polyline>{};
    for (final e in byDay.entries) {
      final day = e.value;
      if (day.length < 2) continue;
      final color = dayColors[e.key % dayColors.length];
      final origin = '${day.first.lat},${day.first.lng}';
      final dest = '${day.last.lat},${day.last.lng}';
      final waypoints = day.length > 2
          ? day.sublist(1, day.length - 1).map((a) => '${a.lat},${a.lng}').join('|')
          : null;
      final cacheKey = '$origin->$dest|$waypoints';
      var route = _routeCache[cacheKey];
      if (route == null) {
        try {
          var url = 'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$dest&key=$_mapsKey';
          if (waypoints != null) url += '&waypoints=$waypoints';
          final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
          final data = jsonDecode(resp.body);
          if (data['status'] == 'OK') {
            final allPts = <LatLng>[];
            for (final leg in data['routes'][0]['legs']) {
              for (final step in leg['steps']) {
                allPts.addAll(_decodePolyline(step['polyline']['points']));
              }
            }
            route = allPts;
          }
        } catch (_) {}
        route ??= [];
        _routeCache[cacheKey] = route;
      }
      if (route.isEmpty) route = day.map((a) => LatLng(a.lat, a.lng)).toList();
      poly.add(Polyline(
        polylineId: PolylineId('day_${e.key}'),
        points: route,
        color: color.withValues(alpha: 0.5),
        width: 4,
        patterns: route.length <= day.length ? [PatternItem.dash(10), PatternItem.gap(8)] : [],
      ));
    }
    if (mounted) setState(() => _polylines = poly);
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
      GoogleMap(
        initialCameraPosition: CameraPosition(target: _center, zoom: 12),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (c) {
          c.setMapStyle(_mapStyle);
          if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
          Future.delayed(const Duration(milliseconds: 500), _fitBounds);
        },
        onCameraMove: (pos) {
          _currentZoom = pos.zoom;
        },
        onCameraIdle: () {
          // Rebuild markers when zoom changes (clustering)
          _rebuild();
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
        left: 0, right: 0,
        child: Center(
          child: GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); _fitBounds(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.zoom_out_map, size: 16, color: Color(0xFF5F6368)),
                SizedBox(width: 6),
                Text('Fit all places', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5F6368))),
              ]),
            ),
          ),
        ),
      ),

      // ── Info card ──
      if (_selected != null && !widget.hideInfoCard)
        AnimatedBuilder(
          animation: _cardAnim,
          builder: (_, __) {
            final slide = Tween<double>(begin: 80, end: 0)
                .animate(CurvedAnimation(parent: _cardAnim, curve: Curves.easeOutBack))
                .value;
            final opacity = _cardAnim.value.clamp(0.0, 1.0);
            return Positioned(
              bottom: 24 + slide, left: 16, right: 16,
              child: Opacity(opacity: opacity, child: _infoCard(_selected!)),
            );
          },
        ),
    ]);
  }

  // ─── White Wanderlog-style info card ──────────────────────
  Widget _infoCard(MapActivity a) {
    final color = _categoryColors[a.category] ?? dayColors[a.dayIndex % dayColors.length];
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Row 1: Number badge + Name + Close
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${a.numberInDay}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(a.name, style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16, fontWeight: FontWeight.w700, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              GestureDetector(
                onTap: () { setState(() => _selected = null); _cardAnim.reverse(); },
                child: const Icon(Icons.close, size: 20, color: Color(0xFF9CA3AF)),
              ),
            ]),
            const SizedBox(height: 10),
            // Row 2: Rating + Google badge + Opening hours
            Row(children: [
              if (a.rating != null) ...[
                const Icon(Icons.star, size: 14, color: Color(0xFFFBBC04)),
                const SizedBox(width: 3),
                Text('${a.rating!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                const SizedBox(width: 6),
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: const Text('G', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
              ],
              if (a.category != null && a.category!.isNotEmpty)
                Text(a.category![0].toUpperCase() + a.category!.substring(1), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              if (a.time.isNotEmpty) ...[
                Text('  ·  ', style: TextStyle(color: Colors.grey.shade400)),
                Text(a.time, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ]),
            const SizedBox(height: 14),
            // Row 3: Action buttons
            Row(children: [
              _outlinePill('Directions', Icons.directions),
              const SizedBox(width: 8),
              _outlinePill('Details', Icons.info_outline),
              const SizedBox(width: 8),
              _outlinePill('Google Maps', Icons.map_outlined),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _outlinePill(String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: const Color(0xFF5F6368)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5F6368))),
        ]),
      ),
    );
  }

  Widget _dot() => Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text('·', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)));
  Widget _chip(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
  );
  Widget _photoPlaceholder(Color c) => Container(color: c.withValues(alpha: 0.15), child: Icon(Icons.place, color: c, size: 22));
}

// ─── Cluster helper ────────────────────────────────────────
class _MarkerItem {
  final MapActivity? activity;
  final List<MapActivity>? activities;
  final double lat;
  final double lng;

  _MarkerItem.single(MapActivity a) : activity = a, activities = null, lat = a.lat, lng = a.lng;
  _MarkerItem.cluster(List<MapActivity> items, this.lat, this.lng) : activity = null, activities = items;

  bool get isCluster => activities != null;
  int get count => activities?.length ?? 1;
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
