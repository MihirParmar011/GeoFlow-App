import 'package:flutter/material.dart';

/// Represents a map tile style with its URL template and attribution.
///
/// Aligned with OpenMapTiles schema and free tile providers as specified
/// in the PRD and TRD documentation.
class MapStyleEntity {
  final String id;
  final String name;
  final String tileUrl;
  final String attribution;
  final IconData icon;

  const MapStyleEntity({
    required this.id,
    required this.name,
    required this.tileUrl,
    required this.attribution,
    required this.icon,
  });

  /// All available map styles — free tile servers, no API key required.
  static const List<MapStyleEntity> availableStyles = [
    MapStyleEntity(
      id: 'street',
      name: 'Street',
      tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors',
      icon: Icons.map,
    ),
    MapStyleEntity(
      id: 'light',
      name: 'Light',
      tileUrl: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
      attribution: '© OpenMapTiles © OpenStreetMap contributors © CARTO',
      icon: Icons.light_mode,
    ),
    MapStyleEntity(
      id: 'dark',
      name: 'Dark',
      tileUrl: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
      attribution: '© OpenMapTiles © OpenStreetMap contributors © CARTO',
      icon: Icons.dark_mode,
    ),
    MapStyleEntity(
      id: 'topo',
      name: 'Terrain',
      tileUrl: 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors © OpenTopoMap (CC-BY-SA)',
      icon: Icons.terrain,
    ),
    MapStyleEntity(
      id: 'satellite',
      name: 'Satellite',
      tileUrl: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      attribution: '© Esri, Maxar, Earthstar Geographics',
      icon: Icons.satellite_alt,
    ),
  ];
}
