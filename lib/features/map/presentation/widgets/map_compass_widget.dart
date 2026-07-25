import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Compass overlay widget that shows the current map rotation
/// and resets to north when tapped (PRD §3.1).
class MapCompassWidget extends StatelessWidget {
  final MapController mapController;

  const MapCompassWidget({super.key, required this.mapController});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MapEvent>(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        final rotation = mapController.camera.rotation;

        // Hide compass when map is facing north (within 1 degree)
        if (rotation.abs() < 1.0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            // Reset rotation to north
            mapController.rotate(0.0);
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF12141C).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Transform.rotate(
              angle: -rotation * (pi / 180),
              child: const Icon(
                Icons.navigation,
                color: Colors.redAccent,
                size: 22,
              ),
            ),
          ),
        );
      },
    );
  }
}
