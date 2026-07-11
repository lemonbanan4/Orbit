import 'dart:ui';
import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;

  const GlassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 56.0, // Matches your original exact height
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // Stretches to match your current layout
      height: height,
      child: DecoratedBox(
        // Soft colored glow beneath the glass, the claymorphism touch
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: onPressed == null
              ? const []
              : [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFF7000FF).withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: -6,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 15.0,
              sigmaY: 15.0,
            ), // Frost effect inside the button boundaries
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                // Crisp, fine glass border outline
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                // Vibrant cyan-to-purple glass gradient
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00E5FF).withValues(alpha: 0.55),
                    const Color(0xFF7000FF).withValues(alpha: 0.45),
                    const Color(0xFF1A1F36).withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.transparent, // Crucial: strips away solid colors
                  shadowColor: Colors.transparent, // Strips away solid shadows
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  text.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
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
