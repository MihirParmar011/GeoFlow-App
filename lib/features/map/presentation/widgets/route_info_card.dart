import 'dart:ui';
import 'package:flutter/material.dart';
import '../providers/route_provider.dart';
import '../../domain/entities/route_entity.dart';

/// Bottom card showing route distance, ETA, travel mode selector,
/// and 3-stage arrival indicator per V2 spec.
class RouteInfoCard extends StatelessWidget {
  final RouteState routeState;
  final ArrivalStatus arrivalStatus;
  final TravelMode selectedMode;
  final void Function(TravelMode mode) onModeChanged;
  final VoidCallback onClose;

  const RouteInfoCard({
    super.key,
    required this.routeState,
    required this.arrivalStatus,
    required this.selectedMode,
    required this.onModeChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final route = routeState.route;
    if (route == null && !routeState.isLoading) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF12141C).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
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

              if (routeState.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                )
              else if (routeState.error != null)
                _buildErrorState(routeState.error!)
              else if (route != null) ...[
                // Arrival status banner
                if (arrivalStatus != ArrivalStatus.inactive)
                  _buildArrivalBanner(),
                if (arrivalStatus != ArrivalStatus.inactive)
                  const SizedBox(height: 12),

                // Distance & ETA
                Row(
                  children: [
                    _buildInfoTile(
                      icon: Icons.straighten,
                      label: 'Distance',
                      value: _formatDistance(routeState.remainingDistance ?? route.distanceMeters),
                    ),
                    const SizedBox(width: 16),
                    _buildInfoTile(
                      icon: Icons.schedule,
                      label: 'ETA',
                      value: _formatDuration(routeState.remainingDuration ?? route.durationSeconds),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Travel mode selector
                Row(
                  children: TravelMode.values.map((mode) {
                    final isSelected = selectedMode == mode;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => onModeChanged(mode),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.cyanAccent.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.cyanAccent.withValues(alpha: 0.5)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _modeIcon(mode),
                                  color: isSelected ? Colors.cyanAccent : Colors.white54,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mode.label,
                                  style: TextStyle(
                                    color: isSelected ? Colors.cyanAccent : Colors.white54,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onClose,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel Route'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArrivalBanner() {
    final config = _arrivalConfig(arrivalStatus);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(config.icon, color: config.color, size: 20),
          const SizedBox(width: 10),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
          const SizedBox(height: 8),
          Text(
            'Route error: $error',
            style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.8), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onClose, child: const Text('Dismiss')),
        ],
      ),
    );
  }

  IconData _modeIcon(TravelMode mode) {
    switch (mode) {
      case TravelMode.driving:
        return Icons.directions_car;
      case TravelMode.walking:
        return Icons.directions_walk;
      case TravelMode.cycling:
        return Icons.directions_bike;
    }
  }

  _ArrivalConfig _arrivalConfig(ArrivalStatus status) {
    switch (status) {
      case ArrivalStatus.heading:
        return const _ArrivalConfig(
          label: 'Heading to destination',
          color: Colors.cyanAccent,
          icon: Icons.navigation,
        );
      case ArrivalStatus.gettingClose:
        return const _ArrivalConfig(
          label: 'Getting close!',
          color: Colors.orangeAccent,
          icon: Icons.near_me,
        );
      case ArrivalStatus.arrived:
        return const _ArrivalConfig(
          label: 'You have arrived!',
          color: Colors.greenAccent,
          icon: Icons.check_circle,
        );
      case ArrivalStatus.inactive:
        return const _ArrivalConfig(
          label: '',
          color: Colors.transparent,
          icon: Icons.circle,
        );
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatDuration(double seconds) {
    final totalMinutes = (seconds / 60).ceil();
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      return '${hours}h ${mins}m';
    }
    return '$totalMinutes min';
  }
}

class _ArrivalConfig {
  final String label;
  final Color color;
  final IconData icon;
  const _ArrivalConfig({required this.label, required this.color, required this.icon});
}
