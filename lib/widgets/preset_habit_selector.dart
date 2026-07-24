import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

/// A curated, categorized library of starter habits. Tapping one closes the
/// sheet and hands (title, icon, color) back to the caller, which opens the
/// pre-filled CreateHabitSheet -- so creation still flows through the app's one
/// battle-tested path. The callback contract is unchanged from the original
/// 5-preset version, so all existing call sites keep working.
class PresetHabitSelector extends StatelessWidget {
  final Function(String title, IconData icon, Color color) onHabitSelected;

  const PresetHabitSelector({super.key, required this.onHabitSelected});

  static const List<_HabitCategory> _categories = [
    _HabitCategory(
      label: 'Fitness',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFFF7A7A),
      habits: [
        _Suggestion('Workout', Icons.fitness_center_rounded),
        _Suggestion('Morning Walk', Icons.directions_walk_rounded),
        _Suggestion('Go for a Run', Icons.directions_run_rounded),
        _Suggestion('Stretch', Icons.accessibility_new_rounded),
        _Suggestion('Drink Water', Icons.water_drop_rounded),
        _Suggestion('10k Steps', Icons.monitor_heart_rounded),
      ],
    ),
    _HabitCategory(
      label: 'Mind',
      icon: Icons.self_improvement_rounded,
      color: Color(0xFFB68BFF),
      habits: [
        _Suggestion('Meditate', Icons.self_improvement_rounded),
        _Suggestion('Deep Breathing', Icons.air_rounded),
        _Suggestion('Gratitude', Icons.favorite_rounded),
        _Suggestion('Mindful Moment', Icons.spa_rounded),
        _Suggestion('Digital Detox', Icons.do_not_disturb_on_rounded),
        _Suggestion('No Social Media', Icons.mobile_off_rounded),
      ],
    ),
    _HabitCategory(
      label: 'Productivity',
      icon: Icons.center_focus_strong_rounded,
      color: Color(0xFF4FD8E8),
      habits: [
        _Suggestion('Deep Work', Icons.center_focus_strong_rounded),
        _Suggestion('Plan My Day', Icons.event_note_rounded),
        _Suggestion('Inbox Zero', Icons.mark_email_read_rounded),
        _Suggestion('Review Goals', Icons.flag_rounded),
        _Suggestion('Single-Task', Icons.checklist_rounded),
        _Suggestion('Tidy Workspace', Icons.cleaning_services_rounded),
      ],
    ),
    _HabitCategory(
      label: 'Growth',
      icon: Icons.local_florist_rounded,
      color: Color(0xFF7BE0A6),
      habits: [
        _Suggestion('Read a Book', Icons.menu_book_rounded),
        _Suggestion('Journal', Icons.edit_note_rounded),
        _Suggestion('Learn Something New', Icons.lightbulb_rounded),
        _Suggestion('Practice a Skill', Icons.handyman_rounded),
        _Suggestion('Listen to a Podcast', Icons.headphones_rounded),
        _Suggestion('Study', Icons.school_rounded),
      ],
    ),
    _HabitCategory(
      label: 'Core',
      icon: Icons.nightlight_round,
      color: Color(0xFFF2C879),
      habits: [
        _Suggestion('Sleep by 11pm', Icons.bedtime_rounded),
        _Suggestion('Wake Up Early', Icons.alarm_rounded),
        _Suggestion('Take Vitamins', Icons.medication_rounded),
        _Suggestion('Eat a Veggie', Icons.local_florist_rounded),
        _Suggestion('Make the Bed', Icons.king_bed_rounded),
        _Suggestion('Limit Sugar', Icons.no_food_rounded),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F36),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
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
              const SizedBox(height: 18),
              const Text(
                'Add a Habit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick a starter, or build your own',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              _CustomHabitButton(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  onHabitSelected('', Icons.star_rounded, const Color(0xFF00E5FF));
                },
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: _categories.length,
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    return _CategorySection(
                      category: cat,
                      onSelected: (s) {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                        onHabitSelected(s.title, s.icon, cat.color);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomHabitButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CustomHabitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0x3300E5FF), Color(0x1A00E5FF)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x6600E5FF)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 20),
            SizedBox(width: 8),
            Text(
              'Create a custom habit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final _HabitCategory category;
  final ValueChanged<_Suggestion> onSelected;

  const _CategorySection({required this.category, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width / 3.4;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, color: category.color, size: 18),
              const SizedBox(width: 8),
              Text(
                category.label,
                style: TextStyle(
                  color: category.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: category.habits.map((s) {
              return GestureDetector(
                onTap: () => onSelected(s),
                child: Container(
                  width: cardWidth,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: category.color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(s.icon, color: category.color, size: 26),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          s.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
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
    );
  }
}

class _HabitCategory {
  final String label;
  final IconData icon;
  final Color color;
  final List<_Suggestion> habits;
  const _HabitCategory({
    required this.label,
    required this.icon,
    required this.color,
    required this.habits,
  });
}

class _Suggestion {
  final String title;
  final IconData icon;
  const _Suggestion(this.title, this.icon);
}
