import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/routine_provider.dart';

class RoutineHeaderInfo extends StatelessWidget {
  final int habitCount;
  final String routineType;
  final String title;

  const RoutineHeaderInfo({
    super.key,
    required this.habitCount,
    required this.routineType,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final routineProvider = context.watch<RoutineProvider>();

    // Calculate live progress directly from the provider
    final completedCount = routineProvider
        .getHabitsForRoutine(routineType)
        .where((h) => routineProvider.isHabitCompleted(h.id))
        .length;

    final progress = habitCount > 0 ? completedCount / habitCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1A1F36),
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        // The Animated Premium Progress Bar
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0.0, end: progress),
          builder: (context, value, _) {
            Widget completedText = Text(
              '${(value * habitCount).round()} of $habitCount Completed',
              style: TextStyle(
                color:
                    value >= 0.999 ? const Color(0xFF00E5FF) : Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: value >= 0.999
                    ? [const Shadow(color: Color(0xFF00E5FF), blurRadius: 8)]
                    : null,
              ),
            );

            if (value >= 0.999) {
              completedText = completedText
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.02, duration: 600.ms);
            }

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    completedText,
                    Text(
                      '${(value * 100).toInt()}%',
                      style: TextStyle(
                        color: value >= 0.999
                            ? const Color(0xFF00E5FF)
                            : Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        shadows: value >= 0.999
                            ? [
                                const Shadow(
                                    color: Color(0xFF00E5FF), blurRadius: 8)
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * value,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
