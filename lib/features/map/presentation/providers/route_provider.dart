import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../data/datasources/osrm_service.dart';
import '../../domain/entities/route_entity.dart';

/// OSRM service provider — singleton instance.
final osrmServiceProvider = Provider<OsrmService>((ref) {
  return OsrmService();
});

/// Currently selected travel mode.
final travelModeProvider = StateProvider<TravelMode>((ref) => TravelMode.driving);

/// Active route state — null when no route is calculated.
final activeRouteProvider = StateNotifierProvider<RouteNotifier, RouteState>((ref) {
  return RouteNotifier(ref);
});

/// Tracks the 3-stage arrival status per V2 spec.
final arrivalStatusProvider = StateProvider<ArrivalStatus>((ref) => ArrivalStatus.inactive);

/// Arrival status stages from V2 Problem 2 fix.
enum ArrivalStatus {
  inactive,     // No route active
  heading,      // "Heading to destination"
  gettingClose, // "Getting close" (< 200m)
  arrived,      // "Arrived" (3 consecutive readings within 15m)
}

class RouteState {
  final RouteEntity? route;
  final bool isLoading;
  final String? error;
  final double? remainingDistance;
  final double? remainingDuration;

  const RouteState({
    this.route,
    this.isLoading = false,
    this.error,
    this.remainingDistance,
    this.remainingDuration,
  });

  RouteState copyWith({
    RouteEntity? route,
    bool? isLoading,
    String? error,
    double? remainingDistance,
    double? remainingDuration,
  }) {
    return RouteState(
      route: route ?? this.route,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingDuration: remainingDuration ?? this.remainingDuration,
    );
  }
}

class RouteNotifier extends StateNotifier<RouteState> {
  final Ref _ref;

  /// Keeps the last N GPS readings for arrival confirmation.
  final List<LatLng> _recentPositions = [];
  static const int _arrivalConfirmCount = 3;
  static const double _arrivalRadiusMeters = 15.0;
  static const double _gettingCloseMeters = 200.0;

  LatLng? _destination;

  RouteNotifier(this._ref) : super(const RouteState());

  /// Calculate a route from [start] to [end].
  Future<void> calculateRoute(LatLng start, LatLng end) async {
    _destination = end;
    _recentPositions.clear();
    _ref.read(arrivalStatusProvider.notifier).state = ArrivalStatus.heading;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final mode = _ref.read(travelModeProvider);
      final service = _ref.read(osrmServiceProvider);
      final route = await service.getRoute(start: start, end: end, mode: mode);

      state = RouteState(
        route: route,
        isLoading: false,
        remainingDistance: route.distanceMeters,
        remainingDuration: route.durationSeconds,
      );
    } catch (e) {
      state = RouteState(isLoading: false, error: e.toString());
    }
  }

  /// Update remaining distance/ETA and check arrival as the user moves.
  void updateWithPosition(LatLng currentPosition) {
    if (state.route == null || _destination == null) return;

    final distCalc = const Distance();
    final distToDest = distCalc.as(
      LengthUnit.Meter,
      currentPosition,
      _destination!,
    );

    // Update remaining distance and approximate remaining duration
    final route = state.route!;
    final fraction = (distToDest / route.distanceMeters).clamp(0.0, 1.0);
    final remainingDuration = route.durationSeconds * fraction;

    state = state.copyWith(
      remainingDistance: distToDest,
      remainingDuration: remainingDuration,
    );

    // --- 3-Stage Arrival Detection (V2 Problem 2) ---
    _recentPositions.add(currentPosition);
    if (_recentPositions.length > _arrivalConfirmCount) {
      _recentPositions.removeAt(0);
    }

    if (distToDest <= _arrivalRadiusMeters &&
        _recentPositions.length >= _arrivalConfirmCount) {
      // Check if ALL recent readings are within arrival radius
      final allClose = _recentPositions.every((pos) {
        final d = distCalc.as(LengthUnit.Meter, pos, _destination!);
        return d <= _arrivalRadiusMeters;
      });
      if (allClose) {
        _ref.read(arrivalStatusProvider.notifier).state = ArrivalStatus.arrived;
        return;
      }
    }

    if (distToDest <= _gettingCloseMeters) {
      _ref.read(arrivalStatusProvider.notifier).state = ArrivalStatus.gettingClose;
    } else {
      _ref.read(arrivalStatusProvider.notifier).state = ArrivalStatus.heading;
    }
  }

  /// Clear the active route.
  void clearRoute() {
    _destination = null;
    _recentPositions.clear();
    _ref.read(arrivalStatusProvider.notifier).state = ArrivalStatus.inactive;
    state = const RouteState();
  }
}
