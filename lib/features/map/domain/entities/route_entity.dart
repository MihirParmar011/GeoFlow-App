import 'package:latlong2/latlong.dart';

/// Route data returned from the OSRM routing service.
class RouteEntity {
  /// The list of points forming the route polyline.
  final List<LatLng> polylinePoints;

  /// Total route distance in meters.
  final double distanceMeters;

  /// Estimated route duration in seconds.
  final double durationSeconds;

  /// Travel mode used for this route.
  final TravelMode travelMode;

  const RouteEntity({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.travelMode,
  });

  /// Human-readable distance string.
  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  /// Human-readable duration string.
  String get formattedDuration {
    final totalMinutes = (durationSeconds / 60).ceil();
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      return '${hours}h ${mins}m';
    }
    return '$totalMinutes min';
  }
}

/// Supported travel modes matching OSRM profiles.
enum TravelMode {
  driving('driving', 'Drive'),
  walking('foot', 'Walk'),
  cycling('bike', 'Cycle');

  final String osrmProfile;
  final String label;
  const TravelMode(this.osrmProfile, this.label);
}
