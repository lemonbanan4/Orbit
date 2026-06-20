import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;

class OrbitConfetti extends StatelessWidget {
  final ConfettiController controller;

  const OrbitConfetti({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ConfettiWidget(
      confettiController: controller,
      blastDirectionality: BlastDirectionality.directional,
      blastDirection: math.pi / 2, // Downwards
      maxBlastForce: 25,
      minBlastForce: 10,
      emissionFrequency: 0.05,
      numberOfParticles: 20,
      gravity: 0.2,
      colors: const [Color(0xFF00E5FF), Color(0xFF7000FF), Colors.white],
    );
  }
}
