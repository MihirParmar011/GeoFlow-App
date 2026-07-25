import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/location_request_entity.dart';
import '../../domain/services/location_share_service.dart';

final locationShareServiceProvider = Provider((ref) {
  return LocationShareService(FirebaseFirestore.instance);
});

// Stream of incoming pending requests for the current user
final incomingRequestsProvider = StreamProvider<List<LocationRequestEntity>>((ref) {
  final user = ref.watch(authStateProvider);
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('location_requests')
      .where('toUserId', isEqualTo: user.id)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => LocationRequestEntity.fromFirestore(doc))
          .where((req) => req.status == 'pending')
          .toList());
});

// Stream of active location sharing sessions where the user is either the sender or receiver
final activeSessionsProvider = StreamProvider<List<LocationRequestEntity>>((ref) {
  final user = ref.watch(authStateProvider);
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('location_requests')
      .where(
        Filter.or(
          Filter('fromUserId', isEqualTo: user.id),
          Filter('toUserId', isEqualTo: user.id),
        ),
      )
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => LocationRequestEntity.fromFirestore(doc))
          .where((req) => req.status == 'active')
          .toList());
});
