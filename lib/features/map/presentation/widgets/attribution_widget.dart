import 'package:flutter/material.dart';

/// Mandatory OSM/tile-provider attribution text overlay.
///
/// Required by OpenMapTiles usage policy and the OpenStreetMap tile servers
/// as documented in `.docks/map/openmaptiles-master/README.md`.
class AttributionWidget extends StatelessWidget {
  final String attribution;

  const AttributionWidget({super.key, required this.attribution});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF12141C).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        attribution,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 9,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
