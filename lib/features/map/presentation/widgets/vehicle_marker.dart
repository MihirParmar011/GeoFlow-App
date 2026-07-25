import 'dart:math';
import 'package:flutter/material.dart';

/// An animated vehicle marker with a pulsing ring and directional indicator.
///
/// The marker shows the user's current position with a compass heading
/// arrow/cone (PRD §3.1 "Directional Live Marker").
class VehicleMarker extends StatefulWidget {
  final Color color;
  final double heading;

  const VehicleMarker({
    super.key,
    required this.color,
    this.heading = 0.0,
  });

  @override
  State<VehicleMarker> createState() => _VehicleMarkerState();
}

class _VehicleMarkerState extends State<VehicleMarker> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer ring
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 24 + (36 * _pulseAnimation.value),
                height: 24 + (36 * _pulseAnimation.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.4 * (1 - _pulseAnimation.value)),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          // Accuracy / glow ring
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.1),
            ),
          ),
          // Directional cone — rotates with heading
          Transform.rotate(
            angle: widget.heading * (pi / 180),
            child: CustomPaint(
              size: const Size(48, 48),
              painter: _DirectionConePainter(color: widget.color),
            ),
          ),
          // Inner dot
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a directional cone/triangle pointing upward (north by default).
class _DirectionConePainter extends CustomPainter {
  final Color color;

  _DirectionConePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, center.dy - 22) // Tip (north)
      ..lineTo(center.dx - 8, center.dy - 6)
      ..lineTo(center.dx + 8, center.dy - 6)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DirectionConePainter oldDelegate) =>
      color != oldDelegate.color;
}
