import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/routine_provider.dart';
import 'common/premium_glass_card.dart';
import '../models/habit.dart';

class RoutineHabitList extends StatelessWidget {
  final List<Habit> habits;
  final Function(String) onHabitToggled;

  const RoutineHabitList({
    super.key,
    required this.habits,
    required this.onHabitToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: habits.map((habit) {
        final isCompleted =
            context.watch<RoutineProvider>().isHabitCompleted(habit.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onHabitToggled(habit.id);
            },
            child: PremiumGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? const Color(0xFF00E5FF)
                          : Colors.transparent,
                      border: Border.all(
                          color: isCompleted
                              ? const Color(0xFF00E5FF)
                              : Colors.white54,
                          width: 2),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF13002B), size: 18)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(habit.title,
                        style: TextStyle(
                            color: isCompleted ? Colors.white54 : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null)),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
