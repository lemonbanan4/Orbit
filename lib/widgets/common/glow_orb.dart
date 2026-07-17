import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, bottom, left, right;

  const GlowOrb({
    super.key,
    required this.color,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        // A true glow — radial falloff to transparent — rather than a
        // hard-edged colored disc (which read as a giant "planet" once the
        // photographic backgrounds were removed).
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
            stops: const [0.0, 1.0],
          ),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
              begin: -30, end: 30, duration: 6.seconds, curve: Curves.easeInOut)
          .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.1, 1.1),
              duration: 8.seconds),
    );
  }
}
