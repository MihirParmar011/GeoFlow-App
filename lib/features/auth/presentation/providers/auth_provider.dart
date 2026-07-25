import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_entity.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository(
  FirebaseAuth.instance,
  FirebaseFirestore.instance,
));

final authStateProvider = StateProvider<UserEntity?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    return UserEntity(
      id: user.uid,
      email: user.email,
      username: user.email?.split('@').first ?? 'User',
      isGuest: user.isAnonymous,
    );
  }
  return null;
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Future<UserEntity?> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final userDoc = await _firestore.collection('users').doc(cred.user!.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      return UserEntity(
        id: cred.user!.uid,
        email: data['email'],
        username: data['username'],
        isGuest: false,
      );
    }
    return null;
  }

  Future<bool> _isUsernameTaken(String username) async {
    final usersSnapshot = await _firestore.collection('users').where('username', isEqualTo: username).get();
    if (usersSnapshot.docs.isNotEmpty) return true;
    
    final guestsSnapshot = await _firestore.collection('guests').where('username', isEqualTo: username).get();
    if (guestsSnapshot.docs.isNotEmpty) return true;
    
    return false;
  }

  Future<UserEntity?> signup(String email, String password, String username) async {
    if (await _isUsernameTaken(username)) {
      throw Exception('Username is already taken.');
    }

    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _firestore.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'username': username,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return UserEntity(
      id: cred.user!.uid,
      email: email,
      username: username,
      isGuest: false,
    );
  }

  Future<UserEntity?> loginAsGuest(String username) async {
    if (await _isUsernameTaken(username)) {
      throw Exception('Username is already taken.');
    }

    // Generate a unique dummy email for the guest to bypass the Anonymous Auth requirement
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final guestEmail = 'guest_$timestamp@aetheris.temp';
    final guestPassword = 'GuestPassword123!';
    
    final cred = await _auth.createUserWithEmailAndPassword(
      email: guestEmail, 
      password: guestPassword,
    );
    
    await _firestore.collection('guests').doc(cred.user!.uid).set({
      'username': username,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return UserEntity(
      id: cred.user!.uid,
      username: username,
      isGuest: true,
    );
  }
  
  Future<void> logout() async {
    await _auth.signOut();
  }
}
