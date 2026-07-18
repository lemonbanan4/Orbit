// lib/services/alchemy_telemetry_service.dart

import '../models/habit.dart';

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
  /// Correlates real per-day completion history between adjacent habit
  /// pairs — previously this generated a Random() variance on top of a
  /// same-day isCompleted check and presented it as "real-time algorithmic
  /// pairings," which was fabricated data dressed up as analysis. Now it's
  /// a genuine co-occurrence rate computed from Habit.history.
  static List<HabitSynergy> computeSynergyMatrix(List<Habit> habits) {
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

    for (int i = 0; i < (habits.length - 1).clamp(0, 3); i++) {
      final hA = habits[i];
      final hB = habits[i + 1];

      // Days both habits have any logged outcome (completed or skipped).
      final sharedDays = hA.history.keys.toSet().intersection(
        hB.history.keys.toSet(),
      );

      String verdict;
      double score;
      if (sharedDays.length < 3) {
        score = 0.0;
        verdict =
            "Not enough shared history yet. Keep logging both of these to reveal their true pattern.";
      } else {
        final aCompletedDays = sharedDays.where((d) => hA.history[d] == true);
        final bothCompleted = aCompletedDays
            .where((d) => hB.history[d] == true)
            .length;
        score = aCompletedDays.isEmpty
            ? 0.0
            : (bothCompleted / aCompletedDays.length) * 100;

        if (score >= 75.0) {
          verdict =
              "Strong Gravitational Pull. On days you complete '${hA.title}', you complete '${hB.title}' too ${score.toStringAsFixed(0)}% of the time.";
        } else {
          verdict =
              "Orbital Variance Detected. On days you complete '${hA.title}', you only complete '${hB.title}' ${score.toStringAsFixed(0)}% of the time. Try pairing their execution windows closer together.";
        }
      }

      pairings.add(
        HabitSynergy(
          habitA: hA.title,
          habitB: hB.title,
          synergyPercentage: double.parse(score.toStringAsFixed(1)),
          cosmicVerdict: verdict,
        ),
      );
    }

    return pairings;
  }
}
