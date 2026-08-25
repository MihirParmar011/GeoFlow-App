import 'dart:math';
import 'package:flutter/material.dart';

/// Custom marker widget for a remote/partner user on the map.
///
/// Displays a circular avatar with a colored ring, optional name label,
/// and a live status dot. Uses purple accent color to distinguish from
/// the local user's cyan marker.
class PartnerMarker extends StatefulWidget {
  final String username;
  final double heading;
  final bool isLive;

  const PartnerMarker({
    super.key,
    required this.username,
    this.heading = 0.0,
    this.isLive = true,
  });

  @override
  State<PartnerMarker> createState() => _PartnerMarkerState();
}

class _PartnerMarkerState extends State<PartnerMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    if (widget.isLive) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(PartnerMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!widget.isLive && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markerColor = widget.isLive ? Colors.purpleAccent : Colors.white38;

    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Pulsing outer ring (only when live)
          if (widget.isLive)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 24 + (30 * _pulseAnimation.value),
                  height: 24 + (30 * _pulseAnimation.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: markerColor.withValues(
                          alpha: 0.3 * (1 - _pulseAnimation.value)),
                      width: 2,
                    ),
                  ),
                );
              },
            ),

          // Glow ring
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: markerColor.withValues(alpha: 0.1),
            ),
          ),

          // Directional cone
          if (widget.isLive && widget.heading != 0.0)
            Transform.rotate(
              angle: widget.heading * (pi / 180),
              child: CustomPaint(
                size: const Size(44, 44),
                painter: _DirectionConePainter(color: markerColor),
              ),
            ),

          // Inner avatar circle
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: markerColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 13,
            ),
          ),

          // Name label below
          Positioned(
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF12141C).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: markerColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                widget.username.length > 8
                    ? '${widget.username.substring(0, 8)}…'
                    : widget.username,
                style: TextStyle(
                  color: widget.isLive ? Colors.white : Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Directional cone painter for partner marker heading.
class _DirectionConePainter extends CustomPainter {
  final Color color;
  _DirectionConePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, center.dy - 20)
      ..lineTo(center.dx - 7, center.dy - 6)
      ..lineTo(center.dx + 7, center.dy - 6)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DirectionConePainter oldDelegate) =>
      color != oldDelegate.color;
}
