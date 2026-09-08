import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../domain/entities/map_style_entity.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../providers/map_style_provider.dart';
import '../providers/search_provider.dart';
import '../providers/route_provider.dart';
import '../widgets/vehicle_marker.dart';
import '../widgets/map_compass_widget.dart';
import '../widgets/scale_bar_widget.dart';
import '../widgets/search_results_overlay.dart';
import '../widgets/route_info_card.dart';
import '../widgets/attribution_widget.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isMapCentered = false;
  bool _isFollowingUser = true;
  bool _showSearchResults = false;

  // Selected Pin State
  LatLng? _selectedPinLocation;
  String _selectedPinName = '';

  // Animation for smooth camera movement
  AnimationController? _flyToController;

  // Heading for directional marker
  double _currentHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        // Small delay to allow tap on result before hiding
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_searchFocusNode.hasFocus) {
            setState(() => _showSearchResults = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _flyToController?.dispose();
    super.dispose();
  }

  /// Animated camera fly-to (TRD §3.2)
  void _animatedMoveTo(LatLng target, double zoom) {
    _flyToController?.dispose();
    _flyToController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    final latTween = Tween<double>(begin: startCenter.latitude, end: target.latitude);
    final lngTween = Tween<double>(begin: startCenter.longitude, end: target.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: zoom);

    final animation = CurvedAnimation(parent: _flyToController!, curve: Curves.easeInOutCubic);

    _flyToController!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    _flyToController!.forward();
  }

  /// Handle search query changes with Nominatim
  void _onSearchChanged(String query) {
    ref.read(searchQueryProvider.notifier).state = query;
    setState(() => _showSearchResults = query.trim().isNotEmpty);
  }

  /// Handle tapping a search result
  void _onPlaceSelected(PlaceEntity place) {
    final latLng = LatLng(place.latitude, place.longitude);
    setState(() {
      _selectedPinLocation = latLng;
      _selectedPinName = place.shortName;
      _showSearchResults = false;
      _isFollowingUser = false;
    });
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    _searchFocusNode.unfocus();
    _animatedMoveTo(latLng, 15.0);
    _showLocationDetailsSheet();
  }

  /// Handle long-press for reverse geocoding (Nominatim /reverse)
  Future<void> _handleLongPress(TapPosition tapPosition, LatLng latLng) async {
    setState(() {
      _selectedPinLocation = latLng;
      _selectedPinName = 'Loading...';
      _isFollowingUser = false;
    });

    _showLocationDetailsSheet();
    _animatedMoveTo(latLng, _mapController.camera.zoom);

    try {
      final service = ref.read(nominatimServiceProvider);
      final place = await service.reverseGeocode(latLng.latitude, latLng.longitude);
      if (place != null && mounted) {
        setState(() => _selectedPinName = place.shortName);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _selectedPinName = 'Unknown Location');
      }
    }
  }

  /// Handle map pan — disable follow-me mode (TRD §3.2)
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _isFollowingUser = false;
    }
  }

  void _showLocationDetailsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF12141C).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.cyanAccent.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.location_on,
                              color: Colors.cyanAccent),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SELECTED LOCATION',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _selectedPinName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.directions),
                            label: const Text('Navigate',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _startNavigation();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() => _selectedPinLocation = null);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Start navigation — calculate route from user location to selected pin
  void _startNavigation() {
    final userLoc = ref.read(locationProvider).valueOrNull;
    if (userLoc == null || _selectedPinLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start navigation — location unavailable.')),
      );
      return;
    }

    ref.read(activeRouteProvider.notifier).calculateRoute(
      userLoc,
      _selectedPinLocation!,
    );
  }

  void _showMapStyleSheet() {
    final currentStyle = ref.read(mapStyleProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF12141C).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Map Type',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: MapStyleEntity.availableStyles.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (_, index) {
                          final style = MapStyleEntity.availableStyles[index];
                          final isSelected = currentStyle.id == style.id;

                          return GestureDetector(
                            onTap: () {
                              ref.read(mapStyleProvider.notifier).setStyle(style);
                              Navigator.pop(ctx);
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.cyanAccent.withValues(alpha: 0.2)
                                        : Colors.white12,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.cyanAccent
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(style.icon,
                                      color: isSelected
                                          ? Colors.cyanAccent
                                          : Colors.white70,
                                      size: 28),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  style.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.cyanAccent
                                        : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(locationProvider);
    final mapStyle = ref.watch(mapStyleProvider);
    final searchResults = ref.watch(searchResultsProvider);
    final routeState = ref.watch(activeRouteProvider);
    final arrivalStatus = ref.watch(arrivalStatusProvider);
    final travelMode = ref.watch(travelModeProvider);

    // Update heading from location point
    ref.listen(locationPointProvider, (previous, next) {
      final val = next.valueOrNull;
      if (val != null) {
        setState(() => _currentHeading = val.heading);
      }
    });

    // Auto-center on first location & follow-me mode
    ref.listen(locationProvider, (previous, next) {
      final loc = next.valueOrNull;
      if (loc != null) {
        if (!_isMapCentered) {
          _isMapCentered = true;
          _mapController.move(loc, 16.0);
        } else if (_isFollowingUser) {
          _mapController.move(loc, _mapController.camera.zoom);
        }

        // Update route ETA if navigation is active
        if (routeState.route != null) {
          ref.read(activeRouteProvider.notifier).updateWithPosition(loc);
        }
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ===== THE MAP =====
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(51.5, -0.09),
              initialZoom: 15.0,
              maxZoom: 18.0,
              onLongPress: _handleLongPress,
              onPositionChanged: _onMapPositionChanged,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(-90, -180),
                  const LatLng(90, 180),
                ),
              ),
            ),
            children: [
              // Layer 1: Base tile layer (TRD §3.1)
              TileLayer(
                urlTemplate: mapStyle.tileUrl,
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.geoflow',
              ),

              // Layer 2: Route polyline (TRD §3.1)
              if (routeState.route != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routeState.route!.polylinePoints,
                      strokeWidth: 5.0,
                      color: _routeColor(routeState.route!.travelMode),
                      borderStrokeWidth: 2.0,
                      borderColor: _routeBorderColor(routeState.route!.travelMode),
                      pattern: routeState.route!.travelMode == TravelMode.walking
                          ? StrokePattern.dashed(segments: const [10, 10])
                          : const StrokePattern.solid(),
                    ),
                  ],
                ),

              // Layer 3: Markers — POIs, search pins, destination (TRD §3.1)
              MarkerLayer(
                markers: [
                  // Selected Pin Marker
                  if (_selectedPinLocation != null)
                    Marker(
                      point: _selectedPinLocation!,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on,
                          color: Colors.redAccent, size: 40),
                    ),
                ],
              ),

              // Layer 4: User location marker (TRD §3.1)
              MarkerLayer(
                markers: [
                  if (locationAsync.valueOrNull != null)
                    Marker(
                      point: locationAsync.valueOrNull!,
                      width: 60,
                      height: 60,
                      child: VehicleMarker(
                        color: Colors.cyanAccent,
                        heading: _currentHeading,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ===== TOP SEARCH BAR =====
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _TopSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  isSearching: searchResults.isLoading,
                  onSearch: _onSearchChanged,
                  onClear: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                    setState(() => _showSearchResults = false);
                  },
                ),
                if (_showSearchResults)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SearchResultsOverlay(
                      results: searchResults.value ?? [],
                      isLoading: searchResults.isLoading,
                      error: searchResults.hasError
                          ? searchResults.error.toString()
                          : null,
                      onPlaceSelected: _onPlaceSelected,
                    ),
                  ),
              ],
            ),
          ),

          // ===== LEFT OVERLAYS: Compass + Scale Bar =====
          Positioned(
            left: 16,
            top: MediaQuery.paddingOf(context).top + 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MapCompassWidget(mapController: _mapController),
                const SizedBox(height: 12),
                ScaleBarWidget(mapController: _mapController),
              ],
            ),
          ),

          // ===== RIGHT SIDE CONTROLS =====
          Positioned(
            right: 16,
            top: 150,
            child: _SideControls(
              isFollowing: _isFollowingUser,
              onLayersTapped: _showMapStyleSheet,
              onZoomIn: () {
                final zoom = _mapController.camera.zoom;
                if (zoom < 18.0) {
                  _mapController.move(
                      _mapController.camera.center, zoom + 1);
                }
              },
              onZoomOut: () {
                final zoom = _mapController.camera.zoom;
                _mapController.move(
                    _mapController.camera.center, zoom - 1);
              },
              onMyLocation: () {
                locationAsync.whenData((loc) {
                  setState(() => _isFollowingUser = true);
                  _animatedMoveTo(loc, 16.0);
                });
              },
            ),
          ),

          // ===== BOTTOM: Attribution =====
          Positioned(
            left: 8,
            bottom: 100,
            child: AttributionWidget(attribution: mapStyle.attribution),
          ),

          // ===== BOTTOM: Route Info Card =====
          if (routeState.route != null || routeState.isLoading)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90,
              child: RouteInfoCard(
                routeState: routeState,
                arrivalStatus: arrivalStatus,
                selectedMode: travelMode,
                onModeChanged: (mode) {
                  ref.read(travelModeProvider.notifier).state = mode;
                  // Recalculate with new mode
                  final userLoc = ref.read(locationProvider).valueOrNull;
                  if (userLoc != null && _selectedPinLocation != null) {
                    ref.read(activeRouteProvider.notifier).calculateRoute(
                      userLoc,
                      _selectedPinLocation!,
                    );
                  }
                },
                onClose: () {
                  ref.read(activeRouteProvider.notifier).clearRoute();
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _routeColor(TravelMode mode) {
    switch (mode) {
      case TravelMode.driving:
        return Colors.blue.shade400;
      case TravelMode.walking:
        return Colors.green.shade400;
      case TravelMode.cycling:
        return Colors.orange.shade400;
    }
  }

  Color _routeBorderColor(TravelMode mode) {
    switch (mode) {
      case TravelMode.driving:
        return Colors.blue.shade800;
      case TravelMode.walking:
        return Colors.green.shade800;
      case TravelMode.cycling:
        return Colors.orange.shade800;
    }
  }
}

// ============================================================
// PRIVATE WIDGETS
// ============================================================

class _TopSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final Function(String) onSearch;
  final VoidCallback onClear;

  const _TopSearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF12141C).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search locations...',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16),
                    border: InputBorder.none,
                  ),
                  onChanged: onSearch,
                ),
              ),
              if (isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.cyanAccent),
                  ),
                ),
              if (controller.text.isNotEmpty && !isSearching)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const VerticalDivider(
                  color: Colors.white24, indent: 12, endIndent: 12),
              const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideControls extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onLayersTapped;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onMyLocation;

  const _SideControls({
    required this.isFollowing,
    required this.onLayersTapped,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildGlassButton(
          icon: Icons.layers,
          onTap: onLayersTapped,
        ),
        const SizedBox(height: 12),
        _buildGlassButton(
          icon: isFollowing ? Icons.gps_fixed : Icons.my_location,
          color: isFollowing
              ? Colors.cyanAccent.withValues(alpha: 0.25)
              : Colors.cyanAccent.withValues(alpha: 0.1),
          iconColor: Colors.cyanAccent,
          onTap: onMyLocation,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF12141C).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white70),
                    onPressed: onZoomIn,
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.white70),
                    onPressed: onZoomOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton(
      {required IconData icon,
      required VoidCallback onTap,
      Color? color,
      Color? iconColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color ??
                  const Color(0xFF12141C).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, color: iconColor ?? Colors.white70),
          ),
        ),
      ),
    );
  }
}
