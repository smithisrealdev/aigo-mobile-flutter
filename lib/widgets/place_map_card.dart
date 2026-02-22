import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/maps_service.dart';

/// Compact map preview card for a single place.
class PlaceMapCard extends StatefulWidget {
  final String placeName;
  final double lat;
  final double lng;
  final String? googleMapsUrl;

  const PlaceMapCard({
    super.key,
    required this.placeName,
    required this.lat,
    required this.lng,
    this.googleMapsUrl,
  });

  @override
  State<PlaceMapCard> createState() => _PlaceMapCardState();
}

class _PlaceMapCardState extends State<PlaceMapCard> {
  final Completer<GoogleMapController> _controller = Completer();

  @override
  Widget build(BuildContext context) {
    final pos = LatLng(widget.lat, widget.lng);

    return GestureDetector(
      onTap: () {
        if (widget.googleMapsUrl != null) {
          MapsService.instance.openInGoogleMaps(widget.googleMapsUrl!);
        }
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: pos, zoom: 15),
                markers: {
                  Marker(
                    markerId: const MarkerId('place'),
                    position: pos,
                    infoWindow: InfoWindow(title: widget.placeName),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure),
                  ),
                },
                onMapCreated: (c) => _controller.complete(c),
                zoomControlsEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                myLocationButtonEnabled: false,
                liteModeEnabled: true,
              ),
              // Overlay label
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Color(0xFF1A5EFF)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.placeName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.googleMapsUrl != null)
                        const Icon(Icons.open_in_new,
                            size: 14, color: Color(0xFF6B7280)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
