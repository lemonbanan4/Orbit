import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/orbit_tokens.dart';

/// Which stylized planet to draw for a constellation habit node.
enum StellarPlanetVariant { fitness, mind, productivity, growth, core }

/// Vector-drawn planets for the constellation mapper, replacing the old
/// photographic PNG assets. Each variant gets its own hue from the token
/// palette plus a distinguishing feature (ring, moon, bands) so nodes stay
/// tellable-apart at a glance.
class StellarPlanet extends StatelessWidget {
  final StellarPlanetVariant variant;
  final double size;

  const StellarPlanet({super.key, required this.variant, this.size = 70});

  static StellarPlanetVariant variantForIcon(String? iconType) {
    switch (iconType) {
      case 'Fitness':
        return StellarPlanetVariant.fitness;
      case 'Mind':
        return StellarPlanetVariant.mind;
      case 'Book':
      case 'Structure':
        return StellarPlanetVariant.productivity;
      case 'Explore':
        return StellarPlanetVariant.growth;
      default:
        return StellarPlanetVariant.core;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _StellarPlanetPainter(variant),
    );
  }
}

class _StellarPlanetPainter extends CustomPainter {
  final StellarPlanetVariant variant;

  _StellarPlanetPainter(this.variant);

  Color get _base {
    switch (variant) {
      case StellarPlanetVariant.fitness:
        return OrbitTokens.morning;
      case StellarPlanetVariant.mind:
        return OrbitTokens.violet;
      case StellarPlanetVariant.productivity:
        return OrbitTokens.teal;
      case StellarPlanetVariant.growth:
        return OrbitTokens.gold;
      case StellarPlanetVariant.core:
        return const Color(0xFF3D5CFF);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Leave headroom so the ring/glow never clips at the widget bounds.
    final r = size.shortestSide * 0.30;
    final base = _base;

    // Soft ambient glow behind everything.
    canvas.drawCircle(
      center,
      r * 1.45,
      Paint()
        ..color = base.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Back half of the ring (drawn before the sphere so it passes behind).
    if (_hasRing) {
      _drawRingArc(canvas, center, r, back: true);
    }

    // The sphere, lit from the upper left.
    final sphere = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.5),
        radius: 1.1,
        colors: [
          Color.lerp(base, Colors.white, 0.45)!,
          base,
          Color.lerp(base, OrbitTokens.ground, 0.62)!,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, sphere);

    // Variant detailing.
    switch (variant) {
      case StellarPlanetVariant.mind:
        _drawBands(canvas, center, r, base);
        break;
      case StellarPlanetVariant.fitness:
        _drawCraters(canvas, center, r);
        break;
      case StellarPlanetVariant.growth:
        _drawMoon(canvas, center, r, base);
        break;
      case StellarPlanetVariant.productivity:
      case StellarPlanetVariant.core:
        break; // Ringed variants stay clean.
    }

    // Front half of the ring.
    if (_hasRing) {
      _drawRingArc(canvas, center, r, back: false);
    }

    // Terminator shadow — a crescent of ground-dark on the lower right.
    final shadow = Path()
      ..addOval(Rect.fromCircle(center: center, radius: r));
    canvas.save();
    canvas.clipPath(shadow);
    canvas.drawCircle(
      center.translate(-r * 0.35, -r * 0.35),
      r * 1.25,
      Paint()
        ..color = OrbitTokens.ground.withValues(alpha: 0.45)
        ..blendMode = BlendMode.darken
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.55,
    );
    canvas.restore();
  }

  bool get _hasRing =>
      variant == StellarPlanetVariant.productivity ||
      variant == StellarPlanetVariant.core;

  void _drawRingArc(Canvas canvas, Offset center, double r,
      {required bool back}) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16
      ..color = Color.lerp(_base, Colors.white, 0.3)!
          .withValues(alpha: back ? 0.35 : 0.8);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.35);
    canvas.scale(1.0, 0.38);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r * 1.55);
    // Back pass sweeps the top half of the ellipse; front pass the bottom.
    canvas.drawArc(rect, back ? math.pi : 0, math.pi, false, ringPaint);
    canvas.restore();
  }

  void _drawBands(Canvas canvas, Offset center, double r, Color base) {
    final band = Paint()
      ..color = Color.lerp(base, Colors.white, 0.25)!.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: r)),
    );
    for (final (dy, width) in [(-0.35, 0.14), (0.05, 0.22), (0.45, 0.12)]) {
      band.strokeWidth = r * width;
      canvas.drawLine(
        center.translate(-r, r * dy + r * 0.12),
        center.translate(r, r * dy - r * 0.12),
        band,
      );
    }
    canvas.restore();
  }

  void _drawCraters(Canvas canvas, Offset center, double r) {
    final crater = Paint()
      ..color = OrbitTokens.ground.withValues(alpha: 0.25);
    canvas.drawCircle(center.translate(r * 0.35, -r * 0.25), r * 0.16, crater);
    canvas.drawCircle(center.translate(-r * 0.25, r * 0.4), r * 0.12, crater);
    canvas.drawCircle(center.translate(-r * 0.45, -r * 0.1), r * 0.09, crater);
  }

  void _drawMoon(Canvas canvas, Offset center, double r, Color base) {
    final moonCenter = center.translate(r * 1.35, -r * 0.9);
    canvas.drawCircle(
      moonCenter,
      r * 0.22,
      Paint()..color = Color.lerp(base, Colors.white, 0.5)!,
    );
  }

  @override
  bool shouldRepaint(_StellarPlanetPainter oldDelegate) =>
      oldDelegate.variant != variant;
}
