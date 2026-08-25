import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/location_point_entity.dart';
import 'location_provider.dart';
import 'live_location_state_provider.dart';
import 'location_share_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final locationSyncProvider = Provider<LocationSyncService>((ref) {
  final service = LocationSyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Intelligent location sync service that publishes location to Firebase
/// whenever sharing is enabled or when the user has active sharing sessions.
class LocationSyncService {
  final Ref _ref;
  Timer? _throttleTimer;
  LocationPointEntity? _latestPoint;
  LocationPointEntity? _lastPushedPoint;
  DateTime? _lastWriteTime;
  bool _isSyncing = false;
  bool _disposed = false;

  /// Minimum distance (meters) before an update write is triggered.
  static const double _minDistanceMeters = 2.0;

  /// Maximum time between writes when sharing (to keep freshness).
  static const Duration _maxWriteInterval = Duration(seconds: 3);

  /// Minimum time between non-forced writes (Firestore rate limit).
  static const Duration _minWriteInterval = Duration(seconds: 1);

  LocationSyncService(this._ref) {
    _init();
  }

  Future<void> _init() async {
    // 1. Try to get initial position immediately so we don't wait for stream
    try {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
      if (!_disposed) {
        _latestPoint = LocationPointEntity(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          heading: pos.heading,
          speed: pos.speed,
          timestamp: pos.timestamp,
        );
      }
    } catch (_) {
      // Stream will provide location shortly
    }

    _startListening();
  }

  void _startListening() {
    // Listen to full GPS data
    _ref.listen<AsyncValue<LocationPointEntity>>(locationPointProvider, (previous, next) {
      final point = next.valueOrNull;
      if (point != null) {
        _latestPoint = point;
        _maybeSync();
      }
    });

    // Listen to active sessions changes
    _ref.listen(activeSessionsProvider, (previous, next) {
      final sessions = next.valueOrNull ?? [];
      if (sessions.isNotEmpty) {
        // Automatically enable sharing when in an active session
        _ref.read(isSharingProvider.notifier).state = true;
        // Trigger instant sync for both sides
        forceSync();
      }
    });

    // Periodic sync for stationary users who are sharing
    _throttleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _maybeSync();
    });
  }

  /// Force an immediate push of the latest location to Firestore.
  Future<void> forceSync() async {
    if (_disposed) return;
    if (_latestPoint == null) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        _latestPoint = LocationPointEntity(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          heading: pos.heading,
          speed: pos.speed,
          timestamp: pos.timestamp,
        );
      } catch (_) {}
    }
    await _syncToFirestore();
  }

  Future<void> _maybeSync() async {
    if (_disposed || _isSyncing) return;

    final user = _ref.read(authStateProvider);
    final isSharing = _ref.read(isSharingProvider);

    if (user == null || _latestPoint == null) return;

    // If not sharing, ensure Firebase reflects that and return
    if (!isSharing) {
      await _setOffline(user.id);
      return;
    }

    // Rate limit check
    if (_lastWriteTime != null) {
      final elapsed = DateTime.now().difference(_lastWriteTime!);
      if (elapsed < _minWriteInterval) return;
    }

    // Distance & time elapsed check
    if (_lastPushedPoint != null && _lastWriteTime != null) {
      final elapsed = DateTime.now().difference(_lastWriteTime!);
      final distance = const Distance().as(
        LengthUnit.Meter,
        LatLng(_lastPushedPoint!.latitude, _lastPushedPoint!.longitude),
        LatLng(_latestPoint!.latitude, _latestPoint!.longitude),
      );

      // Skip if barely moved AND not enough time passed
      if (distance < _minDistanceMeters && elapsed < _maxWriteInterval) {
        return;
      }
    }

    await _syncToFirestore();
  }

  Future<void> _syncToFirestore() async {
    if (_isSyncing || _disposed) return;
    _isSyncing = true;

    try {
      final user = _ref.read(authStateProvider);
      if (user == null || _latestPoint == null) return;

      // Extract session partners
      final sessionsAsync = _ref.read(activeSessionsProvider);
      final List<String> partners = [];
      if (sessionsAsync.hasValue && sessionsAsync.value != null) {
        for (var session in sessionsAsync.value!) {
          if (session.fromUserId != user.id) partners.add(session.fromUserId);
          if (session.toUserId != user.id) partners.add(session.toUserId);
        }
      }

      final point = _latestPoint!;
      await FirebaseFirestore.instance
          .collection('live_locations')
          .doc(user.id)
          .set({
        'latitude': point.latitude,
        'longitude': point.longitude,
        'accuracy': point.accuracy,
        'heading': point.heading,
        'speed': point.speed,
        'timestamp': FieldValue.serverTimestamp(),
        'isSharing': true,
        'isOnline': true,
        'sessionPartners': partners,
      }, SetOptions(merge: true));

      _lastPushedPoint = point;
      _lastWriteTime = DateTime.now();

      _ref.read(connectionQualityProvider.notifier).state = ConnectionQuality.connected;
    } catch (e) {
      _ref.read(connectionQualityProvider.notifier).state = ConnectionQuality.unstable;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _setOffline(String userId) async {
    if (_lastPushedPoint == null && _lastWriteTime == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('live_locations')
          .doc(userId)
          .set({
        'isSharing': false,
        'isOnline': false,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    _lastPushedPoint = null;
    _lastWriteTime = null;
  }

  void dispose() {
    _disposed = true;
    _throttleTimer?.cancel();

    final user = _ref.read(authStateProvider);
    if (user != null) {
      _setOffline(user.id);
    }
  }
}
