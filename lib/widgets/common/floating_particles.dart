import 'package:flutter/material.dart';
import 'dart:math' as math;

class FloatingParticles extends StatefulWidget {
  const FloatingParticles({super.key});

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    // An infinite 10-second loop to continuously drift the stars
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(_particleController.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42); // Fixed seed so they don't jitter

    // Draw 40 floating specks of space dust
    for (int i = 0; i < 40; i++) {
      double startX = random.nextDouble() * size.width;
      double startY = random.nextDouble() * size.height;
      double speed = random.nextDouble() * 0.5 + 0.5; // Varying speeds
      double sizeMod = random.nextDouble() * 1.5 + 0.5; // Varying sizes

      // Calculate drifting Y position (moves upwards endlessly)
      double currentY = startY - (progress * size.height * speed);
      if (currentY < 0) currentY += size.height; // Loop to the bottom

      // Calculate the twinkling opacity using a sine wave
      double opacity = (math.sin((progress * math.pi * 4 * speed) + i) + 1) / 2;
      paint.color = Colors.white.withValues(alpha: opacity * 0.6);

      canvas.drawCircle(Offset(startX, currentY), sizeMod, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
