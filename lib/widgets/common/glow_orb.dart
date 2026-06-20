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
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
