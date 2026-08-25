import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Represents a user's live location state in Firebase.
///
/// Stored at `live_locations/{userId}` in Firestore.
/// Includes sharing state, session authorization, and staleness detection.
class LiveLocationEntity {
  final String userId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double heading;
  final double speed;
  final DateTime timestamp;
  final bool isSharing;
  final bool isOnline;
  final List<String> sessionPartners;

  /// Locations older than this are considered stale.
  static const Duration stalenessThreshold = Duration(seconds: 30);

  const LiveLocationEntity({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.heading,
    required this.speed,
    required this.timestamp,
    required this.isSharing,
    required this.isOnline,
    required this.sessionPartners,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  /// Whether this location data is still considered fresh.
  bool get isFresh =>
      DateTime.now().difference(timestamp) < stalenessThreshold;

  /// Whether coordinates are within valid ranges.
  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  /// Whether this user should be shown as actively live on the map.
  bool get isActiveLive => isSharing && isOnline && isFresh && isValid;

  /// Human-readable status label.
  String get statusLabel {
    if (!isSharing) return 'Sharing off';
    if (!isOnline) return 'Offline';
    if (!isFresh) {
      final ago = DateTime.now().difference(timestamp);
      if (ago.inMinutes > 0) return 'Last seen ${ago.inMinutes}m ago';
      return 'Last seen ${ago.inSeconds}s ago';
    }
    return 'Live now';
  }

  factory LiveLocationEntity.fromFirestore(String docId, Map<String, dynamic> data) {
    return LiveLocationEntity(
      userId: docId,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
      heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
      speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSharing: data['isSharing'] as bool? ?? false,
      isOnline: data['isOnline'] as bool? ?? false,
      sessionPartners: List<String>.from(data['sessionPartners'] ?? []),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'heading': heading,
      'speed': speed,
      'timestamp': FieldValue.serverTimestamp(),
      'isSharing': isSharing,
      'isOnline': isOnline,
      'sessionPartners': sessionPartners,
    };
  }
}
