import 'package:cloud_firestore/cloud_firestore.dart';
import '../entities/location_request_entity.dart';
import '../../../auth/domain/entities/user_entity.dart';

class LocationShareService {
  final FirebaseFirestore _firestore;

  LocationShareService(this._firestore);

  /// Send a location share request to [targetUsername].
  Future<void> sendRequest(UserEntity currentUser, String targetUsername) async {
    final cleanUsername = targetUsername.trim();
    if (cleanUsername.isEmpty) {
      throw Exception('Please enter a valid username');
    }

    // 1. Find the target user by username in users or guests collection
    String? targetUserId;
    String actualTargetUsername = cleanUsername;

    final usersQuery = await _firestore
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();

    if (usersQuery.docs.isNotEmpty) {
      targetUserId = usersQuery.docs.first.id;
      actualTargetUsername = usersQuery.docs.first.data()['username'] ?? cleanUsername;
    } else {
      final guestsQuery = await _firestore
          .collection('guests')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();

      if (guestsQuery.docs.isNotEmpty) {
        targetUserId = guestsQuery.docs.first.id;
        actualTargetUsername = guestsQuery.docs.first.data()['username'] ?? cleanUsername;
      }
    }

    if (targetUserId == null) {
      throw Exception('User "$cleanUsername" not found. Check username and try again.');
    }

    if (targetUserId == currentUser.id) {
      throw Exception('You cannot share location with yourself.');
    }

    // 2. Check if the target user has already sent a pending request to currentUser
    final reversePendingQuery = await _firestore
        .collection('location_requests')
        .where('fromUserId', isEqualTo: targetUserId)
        .where('toUserId', isEqualTo: currentUser.id)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (reversePendingQuery.docs.isNotEmpty) {
      // Mutual request -> instantly accept it
      await acceptRequest(reversePendingQuery.docs.first.id);
      return;
    }

    // 3. Check for existing active or pending sessions
    final existingFrom = await _firestore
        .collection('location_requests')
        .where('fromUserId', isEqualTo: currentUser.id)
        .where('toUserId', isEqualTo: targetUserId)
        .get();

    for (var doc in existingFrom.docs) {
      final status = doc.data()['status'];
      if (status == 'active') {
        throw Exception('You are already actively sharing locations with $actualTargetUsername.');
      }
      if (status == 'pending') {
        throw Exception('Request to $actualTargetUsername is already pending.');
      }
      // Clean up old ended/cancelled/rejected requests
      if (status == 'cancelled' || status == 'rejected' || status == 'ended') {
        await doc.reference.delete();
      }
    }

    final existingTo = await _firestore
        .collection('location_requests')
        .where('fromUserId', isEqualTo: targetUserId)
        .where('toUserId', isEqualTo: currentUser.id)
        .get();

    for (var doc in existingTo.docs) {
      final status = doc.data()['status'];
      if (status == 'active') {
        throw Exception('You are already actively sharing locations with $actualTargetUsername.');
      }
      if (status == 'cancelled' || status == 'rejected' || status == 'ended') {
        await doc.reference.delete();
      }
    }

    // 4. Create new pending request
    final request = LocationRequestEntity(
      id: '',
      fromUserId: currentUser.id,
      fromUsername: currentUser.username ?? 'Explorer',
      toUserId: targetUserId,
      toUsername: actualTargetUsername,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _firestore.collection('location_requests').add(request.toMap());
  }

  /// Accept an incoming location share request.
  Future<void> acceptRequest(String requestId) async {
    await _firestore.collection('location_requests').doc(requestId).update({
      'status': 'active',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Decline/Reject an incoming location share request.
  Future<void> rejectRequest(String requestId) async {
    await _firestore.collection('location_requests').doc(requestId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel an outgoing pending request.
  Future<void> cancelRequest(String requestId) async {
    await _firestore.collection('location_requests').doc(requestId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  /// End an active location sharing session.
  Future<void> endSession(String requestId) async {
    await _firestore.collection('location_requests').doc(requestId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }
}
