import 'package:cloud_firestore/cloud_firestore.dart';
import '../entities/location_request_entity.dart';
import '../../../auth/domain/entities/user_entity.dart';

class LocationShareService {
  final FirebaseFirestore _firestore;

  LocationShareService(this._firestore);

  Future<void> sendRequest(UserEntity currentUser, String targetUsername) async {
    // 1. Find the target user by username in users or guests collection
    String? targetUserId;
    
    final usersQuery = await _firestore.collection('users').where('username', isEqualTo: targetUsername).get();
    if (usersQuery.docs.isNotEmpty) {
      targetUserId = usersQuery.docs.first.id;
    } else {
      final guestsQuery = await _firestore.collection('guests').where('username', isEqualTo: targetUsername).get();
      if (guestsQuery.docs.isNotEmpty) {
        targetUserId = guestsQuery.docs.first.id;
      }
    }

    if (targetUserId == null) {
      throw Exception('User not found');
    }

    if (targetUserId == currentUser.id) {
      throw Exception('You cannot share location with yourself');
    }

    // 2. Create the request
    final request = LocationRequestEntity(
      id: '',
      fromUserId: currentUser.id,
      fromUsername: currentUser.username ?? 'Unknown',
      toUserId: targetUserId,
      toUsername: targetUsername,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _firestore.collection('location_requests').add(request.toMap());
  }

  Future<void> acceptRequest(String requestId) async {
    await _firestore.collection('location_requests').doc(requestId).update({'status': 'active'});
  }

  Future<void> rejectRequest(String requestId) async {
    await _firestore.collection('location_requests').doc(requestId).update({'status': 'rejected'});
  }

  Future<void> endSession(String requestId) async {
    await _firestore.collection('location_requests').doc(requestId).update({'status': 'ended'});
  }
}
