import 'package:geolocator/geolocator.dart';

/// Centralized location permission and service status handling.
///
/// Extracts permission logic from providers to avoid duplication
/// and provides clean status enums for UI decision-making.
enum LocationStatus {
  /// Permission granted and location service is enabled.
  ready,

  /// Location services (GPS) are disabled at the device level.
  serviceDisabled,

  /// Permission was denied (can be re-requested).
  permissionDenied,

  /// Permission permanently denied (must go to app settings).
  permissionDeniedForever,
}

class LocationPermissionService {
  /// Check current status without requesting anything.
  Future<LocationStatus> checkStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationStatus.serviceDisabled;

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        return LocationStatus.permissionDenied;
      case LocationPermission.deniedForever:
        return LocationStatus.permissionDeniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationStatus.ready;
      case LocationPermission.unableToDetermine:
        return LocationStatus.permissionDenied;
    }
  }

  /// Check and request permission if needed. Returns the resulting status.
  Future<LocationStatus> checkAndRequest() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationStatus.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.denied:
        return LocationStatus.permissionDenied;
      case LocationPermission.deniedForever:
        return LocationStatus.permissionDeniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationStatus.ready;
      case LocationPermission.unableToDetermine:
        return LocationStatus.permissionDenied;
    }
  }

  /// Open the device location settings (for serviceDisabled).
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open the app settings (for permissionDeniedForever).
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}
