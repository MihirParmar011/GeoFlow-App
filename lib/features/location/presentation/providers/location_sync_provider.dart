import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'location_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final locationSyncProvider = Provider<LocationSyncService>((ref) {
  final service = LocationSyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class LocationSyncService {
  final Ref _ref;
  Timer? _timer;
  LatLng? _latestLocation;
  LatLng? _lastPushedLocation;
  
  LocationSyncService(this._ref) {
    _startSyncing();
  }
  
  void _startSyncing() {
    // Listen to location updates to keep track of latest location
    _ref.listen<AsyncValue<LatLng>>(locationProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        _latestLocation = next.value;
      }
    });

    // Run a timer every 500ms to push to Firestore
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _syncToFirestore();
    });
  }

  Future<void> _syncToFirestore() async {
    final user = _ref.read(authStateProvider);
    if (user == null || _latestLocation == null) return;
    
    // Only push if location has changed slightly to avoid unnecessary writes
    if (_lastPushedLocation != null) {
      if (_latestLocation!.latitude == _lastPushedLocation!.latitude && 
          _latestLocation!.longitude == _lastPushedLocation!.longitude) {
        return; // Hasn't moved
      }
    }
    
    try {
      await FirebaseFirestore.instance.collection('live_locations').doc(user.id).set({
        'latitude': _latestLocation!.latitude,
        'longitude': _latestLocation!.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      _lastPushedLocation = _latestLocation;
    } catch (e) {
      // Ignore errors for silent background sync
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
