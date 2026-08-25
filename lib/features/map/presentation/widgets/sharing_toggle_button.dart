import 'dart:ui';
import 'package:flutter/material.dart';

/// Compact sharing toggle button for the Live Location screen.
///
/// Shows a pill-shaped control with icon + label that reflects
/// the current sharing state. Uses the app's glassmorphic style.
class SharingToggleButton extends StatelessWidget {
  final bool isSharing;
  final bool isLoading;
  final VoidCallback onToggle;

  const SharingToggleButton({
    super.key,
    required this.isSharing,
    this.isLoading = false,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onToggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSharing
                  ? Colors.cyanAccent.withValues(alpha: 0.15)
                  : const Color(0xFF12141C).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSharing
                    ? Colors.cyanAccent.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isSharing ? Colors.cyanAccent : Colors.white54,
                    ),
                  )
                else
                  Icon(
                    isSharing ? Icons.location_on_rounded : Icons.location_off_rounded,
                    size: 18,
                    color: isSharing ? Colors.cyanAccent : Colors.white54,
                  ),
                const SizedBox(width: 8),
                Text(
                  isSharing ? 'Sharing' : 'Share Location',
                  style: TextStyle(
                    color: isSharing ? Colors.cyanAccent : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
