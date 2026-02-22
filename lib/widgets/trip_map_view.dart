import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Full-screen Google Map showing trip activities as markers + polylines.
class TripMapView extends StatefulWidget {
  /// List of activities with at minimum: name, lat, lng, time.
  final List<MapActivity> activities;

  const TripMapView({super.key, required this.activities});

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  final Completer<GoogleMapController> _controller = Completer();

  Set<Marker> get _markers {
    return widget.activities.asMap().entries.map((entry) {
      final i = entry.key;
      final a = entry.value;
      return Marker(
        markerId: MarkerId('activity_$i'),
        position: LatLng(a.lat, a.lng),
        infoWindow: InfoWindow(title: a.name, snippet: a.time),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }).toSet();
  }

  Set<Polyline> get _polylines {
    if (widget.activities.length < 2) return {};
    final points =
        widget.activities.map((a) => LatLng(a.lat, a.lng)).toList();
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: const Color(0xFF1A5EFF),
        width: 3,
      ),
    };
  }

  LatLng get _center {
    if (widget.activities.isEmpty) return const LatLng(35.6762, 139.6503);
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

/// Simple data class for map activity pins.
class MapActivity {
  final String name;
  final String time;
  final double lat;
  final double lng;

  const MapActivity({
    required this.name,
    required this.time,
    required this.lat,
    required this.lng,
  });
}
