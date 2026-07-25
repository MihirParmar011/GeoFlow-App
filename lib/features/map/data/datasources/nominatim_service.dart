import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/place_entity.dart';

/// Service for calling the Nominatim (OSM) geocoding and reverse-geocoding API.
///
/// Replaces the `geocoding` package with free, cross-platform HTTP calls
/// as specified in the TRD and Map_V1 documentation.
class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'GeoFlow/1.0 (com.example.geoflow)';

  final http.Client _client;

  NominatimService({http.Client? client}) : _client = client ?? http.Client();

  /// Search for places by query string.
  ///
  /// Returns a list of matching places from Nominatim's `/search` endpoint.
  Future<List<PlaceEntity>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'limit': '8',
    });

    final response = await _client.get(uri, headers: {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('Nominatim search failed: ${response.statusCode}');
    }

    final List<dynamic> data = json.decode(response.body);
    return data.map((item) => _parsePlaceFromJson(item)).toList();
  }

  /// Reverse-geocode coordinates to a place name.
  ///
  /// Uses Nominatim's `/reverse` endpoint to get the address at a lat/lng.
  Future<PlaceEntity?> reverseGeocode(double latitude, double longitude) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
      'addressdetails': '1',
    });

    final response = await _client.get(uri, headers: {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('Nominatim reverse failed: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    if (data is Map<String, dynamic> && data.containsKey('display_name')) {
      return _parsePlaceFromJson(data);
    }
    return null;
  }

  PlaceEntity _parsePlaceFromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>?;

    return PlaceEntity(
      displayName: json['display_name'] ?? 'Unknown',
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0.0,
      type: json['type'] ?? 'unknown',
      street: address?['road'] ?? address?['pedestrian'] ?? address?['footway'],
      city: address?['city'] ?? address?['town'] ?? address?['village'],
      state: address?['state'],
      country: address?['country'],
    );
  }
}
