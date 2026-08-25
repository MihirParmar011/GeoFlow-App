import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/map/presentation/screens/map_screen.dart';
import 'features/map/presentation/screens/live_location_screen.dart';
import 'features/location/domain/entities/location_request_entity.dart';
import 'features/auth/presentation/screens/auth_screen.dart';
import 'features/location/presentation/providers/location_sync_provider.dart';
import 'features/location/presentation/providers/location_share_provider.dart';
import 'features/location/presentation/providers/live_location_state_provider.dart';

class MainNavScreen extends ConsumerStatefulWidget {
  const MainNavScreen({super.key});

  @override
  ConsumerState<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends ConsumerState<MainNavScreen> {
  int _currentIndex = 0;
  final Set<String> _handledRequestIds = {};

  final List<Widget> _screens = [
    const MapScreen(),
    const LiveLocationScreen(),
    const AuthScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Start background syncing
    ref.watch(locationSyncProvider);

    // Listen to incoming requests
    ref.listen<AsyncValue<List<LocationRequestEntity>>>(incomingRequestsProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final requests = next.value!;
        for (var request in requests) {
          if (request.status == 'pending' && !_handledRequestIds.contains(request.id)) {
            _handledRequestIds.add(request.id);
            _showIncomingRequestDialog(request);
          }
        }
      }
    });

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onNavTapped: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  void _showIncomingRequestDialog(LocationRequestEntity request) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'IncomingRequest',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) => Center(
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
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12141C).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
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
                        child: const Icon(Icons.share_location_rounded, color: Colors.cyanAccent, size: 28),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Location Share Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${request.fromUsername} wants to share live locations with you in real-time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                ref.read(locationShareServiceProvider).rejectRequest(request.id);
                                Navigator.pop(ctx);
                              },
                              child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await ref.read(locationShareServiceProvider).acceptRequest(request.id);
                                ref.read(isSharingProvider.notifier).state = true;
                                ref.read(locationSyncProvider).forceSync();
                                if (mounted) {
                                  setState(() {
                                    _currentIndex = 1; // Switch to Live screen
                                  });
                                }
                              },
                              child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onNavTapped;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onNavTapped,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF051424).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Icons.explore, 'Map', 0),
                  _buildNavItem(Icons.group, 'Live', 1),
                  _buildNavItem(Icons.person, 'Account', 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onNavTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? Colors.cyanAccent : Colors.white54, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.cyanAccent : Colors.white54,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
