import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../domain/entities/route_entity.dart';

/// Service for calling the OSRM (Open Source Routing Machine) API.
///
/// Calculates routes between two points using the public OSRM demo server.
/// Supports driving, walking, and cycling profiles.
class OsrmService {
  static const String _baseUrl = 'https://router.project-osrm.org';

  final http.Client _client;

  OsrmService({http.Client? client}) : _client = client ?? http.Client();

  /// Calculate a route between two points.
  ///
  /// [start] and [end] are the origin and destination coordinates.
  /// [mode] determines the OSRM profile (driving, foot, or bike).
  Future<RouteEntity> getRoute({
    required LatLng start,
    required LatLng end,
    TravelMode mode = TravelMode.driving,
  }) async {
    final coordinates = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
    final uri = Uri.parse(
      '$_baseUrl/route/v1/${mode.osrmProfile}/$coordinates'
    ).replace(queryParameters: {
      'overview': 'full',
      'geometries': 'geojson',
      'steps': 'false',
    });

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('OSRM route request failed: ${response.statusCode}');
    }

    final data = json.decode(response.body);

    if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
      throw Exception('No route found between the given points.');
    }

    final route = data['routes'][0];
    final geometry = route['geometry'];
    final coordinates_ = geometry['coordinates'] as List;

    // GeoJSON coordinates are [lng, lat], convert to LatLng
    final polylinePoints = coordinates_.map<LatLng>((coord) {
      return LatLng(
        (coord[1] as num).toDouble(),
        (coord[0] as num).toDouble(),
      );
    }).toList();

    return RouteEntity(
      polylinePoints: polylinePoints,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      travelMode: mode,
    );
  }
}
