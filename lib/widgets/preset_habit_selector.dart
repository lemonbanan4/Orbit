import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class PresetHabitSelector extends StatelessWidget {
  final Function(String title, IconData icon, Color color) onHabitSelected;

  const PresetHabitSelector({super.key, required this.onHabitSelected});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> presets = [
      {
        'title': 'Drink Water',
        'icon': Icons.water_drop_rounded,
        'color': Colors.blueAccent,
      },
      {
        'title': 'Read a Book',
        'icon': Icons.menu_book_rounded,
        'color': Colors.orangeAccent,
      },
      {
        'title': 'Meditate',
        'icon': Icons.self_improvement_rounded,
        'color': Colors.purpleAccent,
      },
      {
        'title': 'Workout',
        'icon': Icons.fitness_center_rounded,
        'color': Colors.redAccent,
      },
      {
        'title': 'Journal',
        'icon': Icons.edit_note_rounded,
        'color': Colors.greenAccent,
      },
      {
        'title': 'Custom Habit',
        'icon': Icons.star_rounded, //Icons.add_circle_outline_rounded,
        'color': const Color(0xFF00E5FF),
      },
    ];

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F36),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Choose a Habit",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: presets.map((preset) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context); // Close the selector
                      onHabitSelected(
                        preset['title'] == 'Custom Habit'
                            ? ''
                            : preset['title'],
                        preset['icon'],
                        preset['color'],
                      );
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width / 3.5,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            preset['icon'],
                            color: preset['color'],
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            preset['title'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
