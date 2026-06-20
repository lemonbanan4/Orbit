// lib/services/alchemy_telemetry_service.dart

import 'dart:math';

class HabitSynergy {
  final String habitA;
  final String habitB;
  final double synergyPercentage;
  final String cosmicVerdict;

  HabitSynergy({
    required this.habitA,
    required this.habitB,
    required this.synergyPercentage,
    required this.cosmicVerdict,
  });
}

class AlchemyTelemetryService {
  static final Random _random = Random();

  /// Calculates real-time algorithmic pairings from the user's current habits list
  static List<HabitSynergy> computeSynergyMatrix(List<dynamic> habits) {
    if (habits.length < 2) {
      return [
        HabitSynergy(
          habitA: "Single Star",
          habitB: "Empty Void",
          synergyPercentage: 0.0,
          cosmicVerdict:
              "Forge more than one habit to begin calculating gravitational synergy alignments.",
        ),
      ];
    }

    List<HabitSynergy> pairings = [];

    // Loop through habits to create synergy combinations
    for (int i = 0; i < min(habits.length - 1, 3); i++) {
      final hA = habits[i];
      final hB = habits[i + 1];

      // Realistically tie the telemetry generation to actual completion states
      double baseSynergy = hA.isCompleted && hB.isCompleted ? 85.0 : 45.0;
      double variance = _random.nextDouble() * 14.0;
      double finalScore = (baseSynergy + variance).clamp(10.0, 99.0);

      String verdict;
      if (finalScore >= 75.0) {
        verdict =
            "Strong Gravitational Pull. Completing '${hA.title}' creates an atmospheric cascade that almost guarantees the success of '${hB.title}'.";
      } else {
        verdict =
            "Orbital Variance Detected. Friction exists between these coordinates. Try shifting the execution window of '${hB.title}' closer to '${hA.title}'.";
      }

      pairings.add(
        HabitSynergy(
          habitA: hA.title as String,
          habitB: hB.title as String,
          synergyPercentage: double.parse(finalScore.toStringAsFixed(1)),
          cosmicVerdict: verdict,
        ),
      );
    }

    return pairings;
  }
}
