import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'location_share_provider.dart';

// Represents a remote user's live location
class RemoteUserLocation {
  final String userId;
  final String username;
  final LatLng location;
  final DateTime updatedAt;

  RemoteUserLocation({
    required this.userId,
    required this.username,
    required this.location,
    required this.updatedAt,
  });
}

// Stream of remote locations for all users in active sessions with the current user
final remoteLocationsProvider = StreamProvider<List<RemoteUserLocation>>((ref) {
  final user = ref.watch(authStateProvider);
  final activeSessionsAsync = ref.watch(activeSessionsProvider);

  if (user == null || !activeSessionsAsync.hasValue) {
    return const Stream.empty();
  }

  final sessions = activeSessionsAsync.value!;
  if (sessions.isEmpty) return Stream.value([]);

  // Extract all user IDs we are actively sharing with
  final Set<String> targetUserIds = {};
  for (var session in sessions) {
    if (session.fromUserId != user.id) targetUserIds.add(session.fromUserId);
    if (session.toUserId != user.id) targetUserIds.add(session.toUserId);
  }

  if (targetUserIds.isEmpty) return Stream.value([]);

  // Listen to live_locations collection for these specific users
  // Note: Firestore 'whereIn' supports up to 10 items. For a massive app, you'd need chunking,
  // but this is fine for standard sharing.
  return FirebaseFirestore.instance
      .collection('live_locations')
      .where(FieldPath.documentId, whereIn: targetUserIds.toList())
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Try to find the username from the session list
      String username = 'Unknown';
      for (var session in sessions) {
        if (session.fromUserId == doc.id) {
          username = session.fromUsername;
          break;
        } else if (session.toUserId == doc.id) {
          username = session.toUsername;
          break;
        }
      }

      return RemoteUserLocation(
        userId: doc.id,
        username: username,
        location: LatLng(data['latitude'] as double, data['longitude'] as double),
        updatedAt: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList();
  });
});
