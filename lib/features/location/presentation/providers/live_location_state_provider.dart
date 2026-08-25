import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/location_permission_service.dart';

/// Riverpod provider for the LocationPermissionService singleton.
final locationPermissionServiceProvider = Provider<LocationPermissionService>((ref) {
  return LocationPermissionService();
});

/// Whether the current user has enabled location sharing.
final isSharingProvider = StateProvider<bool>((ref) => false);

/// Connection quality state for UI indicators.
enum ConnectionQuality { connected, unstable, disconnected }

/// Provider that tracks Firebase/network connection quality.
/// Updated by the sync service when writes succeed or fail.
final connectionQualityProvider = StateProvider<ConnectionQuality>((ref) {
  return ConnectionQuality.connected;
});

/// Provider that tracks the current location service availability.
/// Polled when the Live tab is active.
final locationServiceEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(locationPermissionServiceProvider);
  final status = await service.checkStatus();
  return status == LocationStatus.ready;
});
