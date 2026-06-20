import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class StardustBurst extends StatefulWidget {
  final Widget child;
  final ConfettiController controller;
  final int numberOfParticles;
  final double maxBlastForce;
  final double minBlastForce;
  final double emissionFrequency;
  final List<Color>? colors;
  final double gravity;
  final BlastDirectionality blastDirectionality;
  final Path Function(Size)? createParticlePath;

  const StardustBurst(
      {super.key,
      required this.child,
      required this.controller,
      this.numberOfParticles = 20,
      this.maxBlastForce = 20,
      this.minBlastForce = 5,
      this.emissionFrequency = 0.05,
      this.colors,
      this.gravity = 0.1,
      this.blastDirectionality = BlastDirectionality.explosive,
      this.createParticlePath});

  // Custom path to draw a 5-pointed star
  static Path drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = size.width / 2;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(-90);

    path.moveTo(size.width / 2, 0);

    for (int i = 0; i < numberOfPoints; i++) {
      final step = i * degreesPerStep;
      path.lineTo(halfWidth + externalRadius * cos(step + fullAngle),
          halfWidth + externalRadius * sin(step + fullAngle));
      path.lineTo(
          halfWidth +
              internalRadius * cos(step + halfDegreesPerStep + fullAngle),
          halfWidth +
              internalRadius * sin(step + halfDegreesPerStep + fullAngle));
    }
    path.close();
    return path;
  }

  // Custom path to draw a crescent moon shape
  static Path drawMoon(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.arcToPoint(
      Offset(size.width * 0.5, size.height),
      radius: Radius.circular(size.width / 2),
      clockwise: false,
    );
    path.arcToPoint(
      Offset(size.width * 0.5, 0),
      radius: Radius.circular(
          size.width * 0.6), // Shallower curve creates the crescent!
      clockwise: true,
    );
    path.close();
    return path;
  }

  @override
  State<StardustBurst> createState() => _StardustBurstState();
}

class _StardustBurstState extends State<StardustBurst> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ConfettiWidget(
          confettiController: widget.controller,
          blastDirectionality: widget.blastDirectionality,
          shouldLoop: false,
          colors: widget.colors ??
              const [
                Colors.amber,
                Colors.cyanAccent,
                Colors.white,
                Colors.purpleAccent
              ],
          createParticlePath:
              widget.createParticlePath ?? StardustBurst.drawStar,
          maxBlastForce: widget.maxBlastForce,
          minBlastForce: widget.minBlastForce,
          emissionFrequency: widget.emissionFrequency,
          numberOfParticles: widget.numberOfParticles,
          gravity: widget.gravity,
        ),
        widget.child,
      ],
    );
  }
}
