import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// A dynamic scale bar that updates with zoom level (PRD §3.1).
///
/// Shows metric units. Positioned as a map overlay.
class ScaleBarWidget extends StatelessWidget {
  final MapController mapController;

  const ScaleBarWidget({super.key, required this.mapController});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MapEvent>(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        final zoom = mapController.camera.zoom;
        final scaleInfo = _calculateScale(zoom);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF12141C).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: scaleInfo.barWidth,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                scaleInfo.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _ScaleInfo _calculateScale(double zoom) {
    // Approximate meters per pixel at the equator for each zoom level
    final metersPerPixel = 156543.03392 / pow(2, zoom);

    // Target a bar width around 60-100 pixels
    final targetMeters = metersPerPixel * 80;

    // Round to a nice number
    final niceDistances = [
      5, 10, 20, 50, 100, 200, 500,
      1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000,
    ];

    int bestDistance = niceDistances.first;
    for (final d in niceDistances) {
      if (d <= targetMeters * 1.5) {
        bestDistance = d;
      }
    }

    final barWidth = (bestDistance / metersPerPixel).clamp(30.0, 120.0);
    final label = bestDistance >= 1000
        ? '${bestDistance ~/ 1000} km'
        : '$bestDistance m';

    return _ScaleInfo(barWidth: barWidth, label: label);
  }
}

class _ScaleInfo {
  final double barWidth;
  final String label;
  const _ScaleInfo({required this.barWidth, required this.label});
}
