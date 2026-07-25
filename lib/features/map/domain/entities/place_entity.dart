/// A place returned from Nominatim search/reverse geocoding.
class PlaceEntity {
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;
  final String? street;
  final String? city;
  final String? state;
  final String? country;

  const PlaceEntity({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.type = 'unknown',
    this.street,
    this.city,
    this.state,
    this.country,
  });

  /// Short name for display in search results.
  String get shortName {
    final parts = displayName.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return displayName;
  }

  /// Subtitle for search result list items.
  String get subtitle {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }
}
