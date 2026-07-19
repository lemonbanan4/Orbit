import 'dart:ui';

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
      // Real Gaussian blur + radial falloff: an ambient glow, not a
      // hard-edged colored disc (which read as a giant flat planet once
      // the photographic backgrounds were removed).
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0.0)],
              stops: const [0.0, 1.0],
            ),
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
