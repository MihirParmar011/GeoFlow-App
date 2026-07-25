/// Rich location point entity wrapping GPS data.
///
/// Used by the LocationValidator and RouteProvider for ETA recalculation,
/// directional marker heading, and adaptive sampling decisions.
class LocationPointEntity {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double heading;
  final double speed;
  final DateTime timestamp;

  const LocationPointEntity({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.heading,
    required this.speed,
    required this.timestamp,
  });
}
