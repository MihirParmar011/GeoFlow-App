import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/map_style_entity.dart';

/// Provides the currently selected map style.
///
/// Defaults to 'street' (standard OSM tiles). Users can switch
/// between 5 styles: Street, Light, Dark, Terrain, Satellite.
final mapStyleProvider = StateNotifierProvider<MapStyleNotifier, MapStyleEntity>((ref) {
  return MapStyleNotifier();
});

class MapStyleNotifier extends StateNotifier<MapStyleEntity> {
  MapStyleNotifier() : super(MapStyleEntity.availableStyles.first);

  void setStyle(MapStyleEntity style) {
    state = style;
  }

  void setStyleById(String id) {
    final match = MapStyleEntity.availableStyles.firstWhere(
      (s) => s.id == id,
      orElse: () => MapStyleEntity.availableStyles.first,
    );
    state = match;
  }
}
