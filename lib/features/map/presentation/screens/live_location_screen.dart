import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../location/presentation/providers/location_share_provider.dart';
import '../../../location/presentation/providers/remote_locations_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/map_style_provider.dart';
import '../widgets/vehicle_marker.dart';

class LiveLocationScreen extends ConsumerStatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  ConsumerState<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends ConsumerState<LiveLocationScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _friendUsernameController = TextEditingController();
  
  bool _isMapCentered = false;

  // Animation variables
  late AnimationController _myAnimController;
  late Animation<double> _myAnim;
  LatLng? _myOldLocation;
  LatLng? _myCurrentAnimatedLocation;

  // Remote users animation tracking
  late AnimationController _remoteAnimController;
  late Animation<double> _remoteAnim;
  final Map<String, LatLng> _remoteOldLocations = {};
  final Map<String, LatLng> _remoteTargetLocations = {};

  // Heading for directional marker
  double _currentHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _myAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _remoteAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    
    _myAnim = CurvedAnimation(parent: _myAnimController, curve: Curves.linear);
    _remoteAnim = CurvedAnimation(parent: _remoteAnimController, curve: Curves.linear);
    
    _myAnimController.addListener(() {
      if (_myOldLocation != null && _myCurrentAnimatedLocation != null) {
        setState(() {}); // Rebuild to interpolate
      }
    });
    
    _remoteAnimController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _myAnimController.dispose();
    _remoteAnimController.dispose();
    _friendUsernameController.dispose();
    super.dispose();
  }

  LatLng _interpolate(LatLng start, LatLng end, double t) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    );
  }

  void _showAddFriendDialog() {
    _friendUsernameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12141C).withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        title: const Text('Request Live Location', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the username of the person you want to share locations with.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _friendUsernameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Username',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () async {
              final username = _friendUsernameController.text.trim();
              if (username.isEmpty) return;
              
              final currentUser = ref.read(authStateProvider);
              if (currentUser == null) return;
              
              Navigator.pop(ctx);
              
              try {
                await ref.read(locationShareServiceProvider).sendRequest(currentUser, username);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Request sent to $username')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                );
              }
            },
            child: const Text('Send Request', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(locationProvider);
    final mapStyle = ref.watch(mapStyleProvider);

    // Update heading
    ref.listen(locationPointProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        setState(() => _currentHeading = next.value!.heading);
      }
    });

    ref.listen(locationProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final newLoc = next.value!;
        if (!_isMapCentered) {
          _isMapCentered = true;
          _mapController.move(newLoc, 16.0);
          _myOldLocation = newLoc;
          _myCurrentAnimatedLocation = newLoc;
        } else {
          // Animate to new location
          if (_myCurrentAnimatedLocation != null) {
            _myOldLocation = _myCurrentAnimatedLocation;
          } else {
            _myOldLocation = previous?.value ?? newLoc;
          }
          _myCurrentAnimatedLocation = newLoc;
          _myAnimController.forward(from: 0.0);
        }
      }
    });

    ref.listen<AsyncValue<List<RemoteUserLocation>>>(remoteLocationsProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        for (var remoteLoc in next.value!) {
          // If we already have a target, that becomes the old location
          _remoteOldLocations[remoteLoc.userId] = _remoteTargetLocations[remoteLoc.userId] ?? remoteLoc.location;
          _remoteTargetLocations[remoteLoc.userId] = remoteLoc.location;
        }
        _remoteAnimController.forward(from: 0.0);
      }
    });

    final currentMyLoc = _myOldLocation != null && _myCurrentAnimatedLocation != null
        ? _interpolate(_myOldLocation!, _myCurrentAnimatedLocation!, _myAnim.value)
        : locationAsync.value;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Tracking',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: const Color(0xFF12141C).withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // The Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(51.5, -0.09),
              initialZoom: 15.0,
              maxZoom: 18.0,
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
              TileLayer(
                urlTemplate: mapStyle.tileUrl,
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.geoflow',
              ),
              MarkerLayer(
                markers: [
                  // User's own vehicle marker
                  if (currentMyLoc != null)
                    Marker(
                      point: currentMyLoc,
                      width: 60,
                      height: 60,
                      child: VehicleMarker(
                        color: Colors.cyanAccent,
                        heading: _currentHeading,
                      ),
                    ),
                  // Remote friends vehicle markers
                  ..._remoteTargetLocations.keys.map((userId) {
                    final target = _remoteTargetLocations[userId]!;
                    final old = _remoteOldLocations[userId] ?? target;
                    final currentLoc = _interpolate(old, target, _remoteAnim.value);
                    
                    return Marker(
                      point: currentLoc,
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          const VehicleMarker(color: Colors.purpleAccent),
                          Positioned(
                            bottom: -20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purpleAccent.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Quick My Location Button
          Positioned(
            right: 16,
            bottom: 80,
            child: FloatingActionButton(
              heroTag: 'my_location',
              backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
              onPressed: () {
                locationAsync.whenData((loc) {
                  _mapController.move(loc, 16.0);
                });
              },
              child: const Icon(Icons.my_location, color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 130.0),
        child: FloatingActionButton(
          heroTag: 'add_friend',
          onPressed: _showAddFriendDialog,
          backgroundColor: Colors.cyanAccent.withValues(alpha: 0.8),
          elevation: 10,
          child: const Icon(Icons.person_add, color: Colors.black),
        ),
      ),
    );
  }
}
