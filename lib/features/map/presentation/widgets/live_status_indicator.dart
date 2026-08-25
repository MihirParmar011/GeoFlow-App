import 'package:flutter/material.dart';
import '../../../location/presentation/providers/live_location_state_provider.dart';

/// Compact connection quality indicator dot with optional label.
///
/// Displays as a small colored circle:
/// - Green: connected
/// - Orange: unstable
/// - Red: disconnected
class LiveStatusIndicator extends StatelessWidget {
  final ConnectionQuality quality;
  final bool showLabel;

  const LiveStatusIndicator({
    super.key,
    required this.quality,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(quality);
    final label = _labelFor(quality);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Color _colorFor(ConnectionQuality q) {
    switch (q) {
      case ConnectionQuality.connected:
        return const Color(0xFF4ADE80); // Green
      case ConnectionQuality.unstable:
        return Colors.orangeAccent;
      case ConnectionQuality.disconnected:
        return Colors.redAccent;
    }
  }

  String _labelFor(ConnectionQuality q) {
    switch (q) {
      case ConnectionQuality.connected:
        return 'Connected';
      case ConnectionQuality.unstable:
        return 'Unstable';
      case ConnectionQuality.disconnected:
        return 'Disconnected';
    }
  }
}
