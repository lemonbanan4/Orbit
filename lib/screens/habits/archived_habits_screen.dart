import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import '../../theme/orbit_tokens.dart';
import '../../utils/icon_utils.dart';
import '../../widgets/common/premium_glass_card.dart';

/// Habits paused via the "Pause" swipe action -- they keep all their
/// history/stats but drop out of the daily checklist and every completion
/// calculation until resumed here.
class ArchivedHabitsScreen extends StatelessWidget {
  const ArchivedHabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitTokens.ground,
      appBar: AppBar(
        title: const Text(
          'Archived Habits',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<RoutineProvider>(
        builder: (context, routineProvider, child) {
          final archived = routineProvider.archivedHabits;

          if (archived.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No paused habits.\nSwipe a habit and tap "Pause" to '
                      'take a break from it without losing your progress.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: archived.length,
            itemBuilder: (context, index) {
              final habit = archived[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: PremiumGlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        getIconFromCodePoint(habit.iconCodePoint),
                        color: Colors.white54,
                      ),
                    ),
                    title: Text(
                      habit.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${habit.completedDays} days completed lifetime',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    trailing: TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        routineProvider.setHabitArchived(habit.id, false);
                      },
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: OrbitTokens.teal,
                      ),
                      label: const Text(
                        'Resume',
                        style: TextStyle(
                          color: OrbitTokens.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
