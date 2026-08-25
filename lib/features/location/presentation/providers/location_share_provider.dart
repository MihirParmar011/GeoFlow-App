import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/location_request_entity.dart';
import '../../domain/services/location_share_service.dart';

final locationShareServiceProvider = Provider((ref) {
  return LocationShareService(FirebaseFirestore.instance);
});

/// Stream of incoming pending requests for the current user.
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

/// Stream of outgoing pending requests sent by the current user.
final outgoingPendingRequestsProvider = StreamProvider<List<LocationRequestEntity>>((ref) {
  final user = ref.watch(authStateProvider);
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('location_requests')
      .where('fromUserId', isEqualTo: user.id)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => LocationRequestEntity.fromFirestore(doc))
          .where((req) => req.status == 'pending')
          .toList());
});

/// Stream of active location sharing sessions where the user is either sender or receiver.
/// Uses dual stream merging for index-free operation.
final activeSessionsProvider = StreamProvider<List<LocationRequestEntity>>((ref) {
  final user = ref.watch(authStateProvider);
  if (user == null) return const Stream.empty();

  final controller = StreamController<List<LocationRequestEntity>>();
  List<DocumentSnapshot> fromDocs = [];
  List<DocumentSnapshot> toDocs = [];

  void emit() {
    final Map<String, LocationRequestEntity> activeMap = {};
    for (var doc in [...fromDocs, ...toDocs]) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null && data['status'] == 'active') {
        activeMap[doc.id] = LocationRequestEntity.fromFirestore(doc);
      }
    }
    if (!controller.isClosed) {
      controller.add(activeMap.values.toList());
    }
  }

  final sub1 = FirebaseFirestore.instance
      .collection('location_requests')
      .where('fromUserId', isEqualTo: user.id)
      .snapshots()
      .listen((snap) {
    fromDocs = snap.docs;
    emit();
  }, onError: (e) {
    if (!controller.isClosed) controller.addError(e);
  });

  final sub2 = FirebaseFirestore.instance
      .collection('location_requests')
      .where('toUserId', isEqualTo: user.id)
      .snapshots()
      .listen((snap) {
    toDocs = snap.docs;
    emit();
  }, onError: (e) {
    if (!controller.isClosed) controller.addError(e);
  });

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    controller.close();
  });

  return controller.stream;
});
