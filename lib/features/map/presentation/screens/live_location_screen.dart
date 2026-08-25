import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../location/presentation/providers/location_share_provider.dart';
import '../../../location/presentation/providers/remote_locations_provider.dart';
import '../../../location/presentation/providers/live_location_state_provider.dart';
import '../../../location/presentation/providers/location_sync_provider.dart';
import '../../../location/domain/services/location_permission_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/map_style_provider.dart';
import '../widgets/vehicle_marker.dart';
import '../widgets/partner_marker.dart';
import '../widgets/live_user_info_panel.dart';
import '../widgets/sharing_toggle_button.dart';
import '../widgets/live_status_indicator.dart';
import '../widgets/location_off_dialog.dart';

class LiveLocationScreen extends ConsumerStatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  ConsumerState<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends ConsumerState<LiveLocationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final TextEditingController _friendUsernameController = TextEditingController();

  bool _isMapReady = false;
  bool _initialCameraDone = false;
  bool _userHasInteracted = false;

  // Smooth animation for own marker
  late AnimationController _myAnimController;
  late Animation<double> _myAnim;
  LatLng? _myOldLocation;
  LatLng? _myTargetLocation;

  // Smooth animation for remote markers
  late AnimationController _remoteAnimController;
  late Animation<double> _remoteAnim;
  final Map<String, LatLng> _remoteOldLocations = {};
  final Map<String, LatLng> _remoteTargetLocations = {};

  // Heading
  double _currentHeading = 0.0;

  // Camera fly-to animation
  AnimationController? _flyToController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _myAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _remoteAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _myAnim = CurvedAnimation(parent: _myAnimController, curve: Curves.easeInOutCubic);
    _remoteAnim = CurvedAnimation(parent: _remoteAnimController, curve: Curves.easeInOutCubic);

    _myAnimController.addListener(_onAnimTick);
    _remoteAnimController.addListener(_onAnimTick);
  }

  void _onAnimTick() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(locationServiceEnabledProvider);
      ref.invalidate(locationProvider);
      ref.invalidate(locationPointProvider);
      ref.read(locationSyncProvider).forceSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _myAnimController.removeListener(_onAnimTick);
    _remoteAnimController.removeListener(_onAnimTick);
    _myAnimController.dispose();
    _remoteAnimController.dispose();
    _flyToController?.dispose();
    _friendUsernameController.dispose();
    super.dispose();
  }

  LatLng _interpolate(LatLng start, LatLng end, double t) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    );
  }

  void _animatedMoveTo(LatLng target, double zoom) {
    if (!_isMapReady) return;
    _flyToController?.dispose();
    _flyToController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    final latTween = Tween<double>(begin: startCenter.latitude, end: target.latitude);
    final lngTween = Tween<double>(begin: startCenter.longitude, end: target.longitude);
    final zoomTween = Tween<double>(begin: startZoom, end: zoom);

    final curved = CurvedAnimation(parent: _flyToController!, curve: Curves.easeInOutCubic);

    _flyToController!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
      );
    });

    _flyToController!.forward();
  }

  void _fitToBothUsers() {
    if (!_isMapReady) return;

    final myLoc = _myTargetLocation ?? ref.read(locationProvider).valueOrNull;
    final remoteUsers = ref.read(remoteLocationsProvider).valueOrNull ?? [];
    final activeLive = remoteUsers.where((u) => u.isActiveLive).toList();

    if (myLoc == null && activeLive.isEmpty) return;

    final List<LatLng> points = [];
    if (myLoc != null) points.add(myLoc);
    for (var u in activeLive) {
      if (u.location != null) points.add(u.location!);
    }

    if (points.length == 1) {
      _animatedMoveTo(points.first, 16.0);
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
        maxZoom: 17,
      ),
    );
  }

  void _handleSharingToggle() async {
    final currentlySharing = ref.read(isSharingProvider);

    if (!currentlySharing) {
      final permService = ref.read(locationPermissionServiceProvider);
      final status = await permService.checkAndRequest();

      if (!mounted) return;

      switch (status) {
        case LocationStatus.serviceDisabled:
          LocationOffDialog.show(
            context,
            onTurnOn: () async {
              await permService.openLocationSettings();
            },
            onDismiss: () {},
          );
          return;
        case LocationStatus.permissionDenied:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required to share.')),
          );
          return;
        case LocationStatus.permissionDeniedForever:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Open app settings to grant location permission.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  permService.openAppSettings();
                },
              ),
            ),
          );
          await permService.openAppSettings();
          return;
        case LocationStatus.ready:
          break;
      }
    }

    final nextSharing = !currentlySharing;
    ref.read(isSharingProvider.notifier).state = nextSharing;
    if (nextSharing) {
      ref.read(locationSyncProvider).forceSync();
    }
  }

  void _showAddFriendDialog() {
    _friendUsernameController.clear();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AddFriend',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (dialogContext, secondaryAnim, tertiaryAnim) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              constraints: const BoxConstraints(maxWidth: 360),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12141C).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.person_add_rounded, color: Colors.cyanAccent, size: 28),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Share Live Location',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the username of the person you want to share locations with.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: TextField(
                            controller: _friendUsernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.alternate_email,
                                  color: Colors.white.withValues(alpha: 0.5), size: 20),
                              hintText: 'Username',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final username = _friendUsernameController.text.trim();
                              if (username.isEmpty) return;

                              final currentUser = ref.read(authStateProvider);
                              if (currentUser == null) return;

                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(dialogContext);

                              try {
                                await ref
                                    .read(locationShareServiceProvider)
                                    .sendRequest(currentUser, username);

                                // Automatically turn on sharing and sync location
                                ref.read(isSharingProvider.notifier).state = true;
                                ref.read(locationSyncProvider).forceSync();

                                messenger.showSnackBar(
                                  SnackBar(content: Text('Request sent to $username!')),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceAll('Exception: ', '')),
                                    backgroundColor: Colors.redAccent.shade700,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Send Request',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(foregroundColor: Colors.white54),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPartnerDetailsSheet(RemoteUserLocation remote, String? sessionId) {
    final myLoc = ref.read(locationProvider).valueOrNull;
    final distStr = myLoc != null ? remote.distanceStringFrom(myLoc) : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141C).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 20),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: remote.isActiveLive
                              ? Colors.purpleAccent.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.purpleAccent, size: 30),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      remote.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: remote.isActiveLive ? const Color(0xFF4ADE80) : Colors.white38,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          remote.statusLabel,
                          style: TextStyle(
                            color: remote.isActiveLive ? const Color(0xFF4ADE80) : Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailTile(
                            icon: Icons.straighten_rounded,
                            label: 'Distance',
                            value: distStr ?? '—',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDetailTile(
                            icon: Icons.gps_fixed_rounded,
                            label: 'Accuracy',
                            value: '±${remote.accuracy.toStringAsFixed(0)}m',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (remote.hasValidLocation)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                              label: const Text('Center', style: TextStyle(fontWeight: FontWeight.w600)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _animatedMoveTo(remote.location!, 16.0);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent.withValues(alpha: 0.18),
                                foregroundColor: Colors.purpleAccent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        if (sessionId != null) ...[
                          if (remote.hasValidLocation) const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.link_off_rounded, size: 18),
                              label: const Text('Stop Sharing', style: TextStyle(fontWeight: FontWeight.w600)),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(ctx);
                                await ref.read(locationShareServiceProvider).endSession(sessionId);
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Stopped sharing with ${remote.username}')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(locationProvider);
    final mapStyle = ref.watch(mapStyleProvider);
    final remoteAsync = ref.watch(remoteLocationsProvider);
    final activeSessionsAsync = ref.watch(activeSessionsProvider);
    final outgoingPendingAsync = ref.watch(outgoingPendingRequestsProvider);
    final isSharing = ref.watch(isSharingProvider);
    final connectionQuality = ref.watch(connectionQualityProvider);
    final user = ref.watch(authStateProvider);

    // Update heading
    ref.listen(locationPointProvider, (previous, next) {
      final val = next.valueOrNull;
      if (val != null && mounted) {
        setState(() => _currentHeading = val.heading);
      }
    });

    // Animate own marker
    ref.listen(locationProvider, (previous, next) {
      final newLoc = next.valueOrNull;
      if (newLoc != null) {
        if (!_initialCameraDone) {
          _myOldLocation = newLoc;
          _myTargetLocation = newLoc;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMapReady && !_initialCameraDone) {
              _initialCameraDone = true;
              _fitToBothUsers();
            }
          });
        } else {
          _myOldLocation = _myTargetLocation ?? newLoc;
          _myTargetLocation = newLoc;
          _myAnimController.forward(from: 0.0);
        }
      }
    });

    // Animate remote markers
    ref.listen<AsyncValue<List<RemoteUserLocation>>>(remoteLocationsProvider, (previous, next) {
      final val = next.valueOrNull;
      if (val != null) {
        for (var remoteLoc in val) {
          if (remoteLoc.location != null) {
            _remoteOldLocations[remoteLoc.userId] =
                _remoteTargetLocations[remoteLoc.userId] ?? remoteLoc.location!;
            _remoteTargetLocations[remoteLoc.userId] = remoteLoc.location!;
          }
        }
        _remoteAnimController.forward(from: 0.0);

        if (!_userHasInteracted && _initialCameraDone) {
          _fitToBothUsers();
        }
      }
    });

    // Interpolated own location
    final currentMyLoc = _myOldLocation != null && _myTargetLocation != null
        ? _interpolate(_myOldLocation!, _myTargetLocation!, _myAnim.value)
        : locationAsync.valueOrNull;

    // Remote users & active sessions
    final remoteUsers = remoteAsync.valueOrNull ?? [];
    final activeSessions = activeSessionsAsync.valueOrNull ?? [];
    final outgoingPending = outgoingPendingAsync.valueOrNull ?? [];
    final primaryRemote = remoteUsers.isNotEmpty ? remoteUsers.first : null;
    final primaryPending = outgoingPending.isNotEmpty ? outgoingPending.first : null;

    final myLoc = locationAsync.valueOrNull;
    final distStr =
        primaryRemote != null && myLoc != null ? primaryRemote.distanceStringFrom(myLoc) : null;

    // Find session ID for primary remote user
    String? primarySessionId;
    if (primaryRemote != null && user != null) {
      for (var s in activeSessions) {
        if (s.fromUserId == primaryRemote.userId || s.toUserId == primaryRemote.userId) {
          primarySessionId = s.id;
          break;
        }
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // === MAP ===
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(51.5, -0.09),
              initialZoom: 15.0,
              maxZoom: 18.0,
              onMapReady: () {
                _isMapReady = true;
                if (_myTargetLocation != null && !_initialCameraDone) {
                  _initialCameraDone = true;
                  _fitToBothUsers();
                }
              },
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) _userHasInteracted = true;
              },
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
                  // Own marker (local-first)
                  if (currentMyLoc != null)
                    Marker(
                      point: currentMyLoc,
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () => _handleSharingToggle(),
                        child: VehicleMarker(
                          color: Colors.cyanAccent,
                          heading: _currentHeading,
                        ),
                      ),
                    ),

                  // Remote user markers
                  ...remoteUsers.where((u) => u.isActiveLive).map((remote) {
                    final target = _remoteTargetLocations[remote.userId] ?? remote.location!;
                    final old = _remoteOldLocations[remote.userId] ?? target;
                    final currentLoc = _interpolate(old, target, _remoteAnim.value);

                    String? sId;
                    for (var s in activeSessions) {
                      if (s.fromUserId == remote.userId || s.toUserId == remote.userId) {
                        sId = s.id;
                        break;
                      }
                    }

                    return Marker(
                      point: currentLoc,
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: () => _showPartnerDetailsSheet(remote, sId),
                        child: PartnerMarker(
                          username: remote.username,
                          heading: remote.heading,
                          isLive: remote.isActiveLive,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // === TOP BAR ===
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: const Color(0xFF12141C).withValues(alpha: 0.75),
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + 8,
                    left: 20,
                    right: 20,
                    bottom: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.share_location_rounded, color: Colors.cyanAccent, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Live Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      LiveStatusIndicator(quality: connectionQuality),
                      const Spacer(),
                      // Add friend / share button
                      if (user != null)
                        GestureDetector(
                          onTap: _showAddFriendDialog,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.person_add_rounded, color: Colors.cyanAccent, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // === RIGHT SIDE CONTROLS ===
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 80,
            child: Column(
              children: [
                _buildMapButton(
                  icon: Icons.fit_screen_rounded,
                  onTap: () {
                    _userHasInteracted = false;
                    _fitToBothUsers();
                  },
                  tooltip: 'Fit both',
                ),
                const SizedBox(height: 10),
                _buildMapButton(
                  icon: Icons.my_location_rounded,
                  onTap: () {
                    locationAsync.whenData((loc) {
                      _animatedMoveTo(loc, 16.0);
                    });
                  },
                  iconColor: Colors.cyanAccent,
                  tooltip: 'My location',
                ),
              ],
            ),
          ),

          // === SHARING TOGGLE ===
          Positioned(
            left: 16,
            top: MediaQuery.paddingOf(context).top + 80,
            child: SharingToggleButton(
              isSharing: isSharing,
              onToggle: _handleSharingToggle,
            ),
          ),

          // === BOTTOM INFO PANEL ===
          Positioned(
            left: 16,
            right: 16,
            bottom: 90,
            child: LiveUserInfoPanel(
              remoteUser: primaryRemote,
              distanceString: distStr,
              pendingOutgoingRequest: primaryPending,
              onCenterOnUser: primaryRemote != null && primaryRemote.hasValidLocation
                  ? () => _animatedMoveTo(primaryRemote.location!, 16.0)
                  : null,
              onEndSession: primarySessionId != null
                  ? () async {
                      final sId = primarySessionId!;
                      final messenger = ScaffoldMessenger.of(context);
                      await ref.read(locationShareServiceProvider).endSession(sId);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Location sharing ended.')),
                      );
                    }
                  : null,
              onCancelPendingRequest: primaryPending != null
                  ? () async {
                      final req = primaryPending;
                      final messenger = ScaffoldMessenger.of(context);
                      await ref.read(locationShareServiceProvider).cancelRequest(req.id);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Cancelled request to ${req.toUsername}')),
                      );
                    }
                  : null,
              onShareWithFriend: _showAddFriendDialog,
            ),
          ),

          // === NOT LOGGED IN STATE ===
          if (user == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF12141C).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded,
                              color: Colors.white.withValues(alpha: 0.3), size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Sign in to use Live Location',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create an account or sign in to share your live location with others.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    String? tooltip,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF12141C).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: iconColor ?? Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }
}
