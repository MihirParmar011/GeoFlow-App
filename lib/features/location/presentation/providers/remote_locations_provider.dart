import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'location_share_provider.dart';

/// Enhanced remote user location entity with full metadata for live UI rendering.
class RemoteUserLocation {
  final String userId;
  final String username;
  final LatLng? location;
  final double accuracy;
  final double heading;
  final double speed;
  final bool isSharing;
  final bool isOnline;
  final DateTime updatedAt;

  RemoteUserLocation({
    required this.userId,
    required this.username,
    this.location,
    required this.accuracy,
    required this.heading,
    required this.speed,
    required this.isSharing,
    required this.isOnline,
    required this.updatedAt,
  });

  /// Whether this user has valid non-zero GPS coordinates.
  bool get hasValidLocation =>
      location != null &&
      (location!.latitude != 0.0 || location!.longitude != 0.0);

  /// Whether this user's location was updated within the last 5 minutes.
  bool get isFresh =>
      DateTime.now().difference(updatedAt) < const Duration(minutes: 5);

  /// Whether this user should be displayed as actively live on the map.
  bool get isActiveLive => isSharing && isOnline && hasValidLocation;

  /// Human-readable status label for UI.
  String get statusLabel {
    if (!hasValidLocation) return 'Connecting...';
    if (!isSharing) return 'Sharing off';
    if (!isOnline) return 'Offline';
    final ago = DateTime.now().difference(updatedAt);
    if (ago.inSeconds < 10) return 'Live now';
    if (ago.inMinutes == 0) return 'Updated ${ago.inSeconds}s ago';
    if (ago.inMinutes < 60) return 'Last seen ${ago.inMinutes}m ago';
    return 'Offline';
  }

  /// Calculate distance from a given position (in meters).
  double? distanceFrom(LatLng from) {
    if (!hasValidLocation) return null;
    return const Distance().as(LengthUnit.Meter, from, location!);
  }

  /// Human-readable distance string.
  String? distanceStringFrom(LatLng from) {
    final meters = distanceFrom(from);
    if (meters == null) return null;
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}

/// Stream of remote locations for all users in active sessions with the current user.
final remoteLocationsProvider = StreamProvider<List<RemoteUserLocation>>((ref) {
  final user = ref.watch(authStateProvider);
  final activeSessionsAsync = ref.watch(activeSessionsProvider);

  if (user == null || !activeSessionsAsync.hasValue) {
    return const Stream.empty();
  }

  final sessions = activeSessionsAsync.value!;
  if (sessions.isEmpty) return Stream.value([]);

  // Map of targetUserId -> targetUsername
  final Map<String, String> partnerUsernames = {};
  for (var session in sessions) {
    if (session.fromUserId != user.id) {
      partnerUsernames[session.fromUserId] = session.fromUsername;
    }
    if (session.toUserId != user.id) {
      partnerUsernames[session.toUserId] = session.toUsername;
    }
  }

  if (partnerUsernames.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('live_locations')
      .where(FieldPath.documentId, whereIn: partnerUsernames.keys.toList())
      .snapshots()
      .map((snapshot) {
    final Map<String, RemoteUserLocation> result = {};

    // First populate active partners with default state
    for (var entry in partnerUsernames.entries) {
      result[entry.key] = RemoteUserLocation(
        userId: entry.key,
        username: entry.value,
        location: null,
        accuracy: 0.0,
        heading: 0.0,
        speed: 0.0,
        isSharing: true,
        isOnline: true,
        updatedAt: DateTime.now(),
      );
    }

    // Update with actual Firestore location data
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final username = partnerUsernames[doc.id] ?? 'Explorer';
      final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;

      result[doc.id] = RemoteUserLocation(
        userId: doc.id,
        username: username,
        location: (lat != 0.0 || lng != 0.0) ? LatLng(lat, lng) : null,
        accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
        heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
        speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
        isSharing: data['isSharing'] as bool? ?? true,
        isOnline: data['isOnline'] as bool? ?? true,
        updatedAt: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }

    return result.values.toList();
  });
});
