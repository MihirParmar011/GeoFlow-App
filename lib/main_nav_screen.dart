import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/map/presentation/screens/map_screen.dart';
import 'features/map/presentation/screens/live_location_screen.dart';
import 'features/location/domain/entities/location_request_entity.dart';
import 'features/auth/presentation/screens/auth_screen.dart';
import 'features/location/presentation/providers/location_sync_provider.dart';
import 'features/location/presentation/providers/location_share_provider.dart';

class MainNavScreen extends ConsumerStatefulWidget {
  const MainNavScreen({super.key});

  @override
  ConsumerState<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends ConsumerState<MainNavScreen> {
  int _currentIndex = 0;

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
          // If we haven't shown a dialog for this request yet
          if (request.status == 'pending') {
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

  void _showIncomingRequestDialog(var request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12141C).withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        title: const Text('Location Share Request', style: TextStyle(color: Colors.white)),
        content: Text(
          '${request.fromUsername} wants to share live locations with you.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(locationShareServiceProvider).rejectRequest(request.id);
              Navigator.pop(ctx);
            },
            child: const Text('Decline', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () {
              ref.read(locationShareServiceProvider).acceptRequest(request.id);
              Navigator.pop(ctx);
              // Switch to live location screen
              setState(() {
                _currentIndex = 1;
              });
            },
            child: const Text('Accept', style: TextStyle(color: Colors.black)),
          ),
        ],
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
    // Smaller, more accessible floating bottom nav
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 56, // Reduced height
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
