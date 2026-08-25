import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationValidator {
  Position? _lastValidPosition;

  bool isValid(Position newPosition) {
    // 1. First reading is always accepted
    if (_lastValidPosition == null) {
      _lastValidPosition = newPosition;
      return true;
    }

    // 2. Reject only if accuracy is extremely poor (> 250 meters)
    // to ensure indoor and mobile testing works smoothly
    if (newPosition.accuracy > 250.0) {
      return false;
    }

    // 3. Reject out-of-order timestamps
    if (newPosition.timestamp.isBefore(_lastValidPosition!.timestamp)) {
      return false;
    }

    // 4. Reject impossible speeds (> 80 m/s or ~288 km/h)
    final distanceHelper = const Distance();
    final distanceInMeters = distanceHelper.as(
      LengthUnit.Meter,
      LatLng(_lastValidPosition!.latitude, _lastValidPosition!.longitude),
      LatLng(newPosition.latitude, newPosition.longitude),
    );

    final timeDiffInSeconds = newPosition.timestamp.difference(_lastValidPosition!.timestamp).inSeconds;
    
    if (timeDiffInSeconds > 0) {
      final speedMetersPerSecond = distanceInMeters / timeDiffInSeconds;
      if (speedMetersPerSecond > 80.0) {
        return false; // Jumped too fast (teleportation anomaly)
      }
    }

    _lastValidPosition = newPosition;
    return true;
  }
}
