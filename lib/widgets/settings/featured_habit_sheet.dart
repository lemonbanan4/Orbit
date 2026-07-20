import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/routine_provider.dart';
import '../../theme/orbit_tokens.dart';
import '../../utils/icon_utils.dart';

/// Lets the user pick which habit gets pinned to the iOS/Android "Habit
/// Widget" home-screen widget -- RoutineProvider.setFeaturedHabit() pushes
/// that habit's title + Habit.computeCurrentStreak() to it on every
/// selection, toggle, and daily reset. Mirrors NebulaThemeSheet's
/// tap-to-select-immediately style (no separate Save button).
class FeaturedHabitSheet extends StatelessWidget {
  const FeaturedHabitSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const FeaturedHabitSheet(),
    );
  }

  Future<void> _select(BuildContext context, String? habitId) async {
    HapticFeedback.selectionClick();
    final provider = context.read<RoutineProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final error = await provider.setFeaturedHabit(habitId);
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          habitId == null
              ? 'Habit widget cleared.'
              : 'Pinned to your home-screen widget.',
        ),
        backgroundColor: OrbitTokens.teal.withValues(alpha: 0.9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoutineProvider>(
      builder: (context, provider, _) {
        final habits = provider.habits.values
            .where((h) => !h.isArchived)
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
        final featuredId = provider.featuredHabitId;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            decoration: const BoxDecoration(
              color: OrbitTokens.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Habit Widget',
                  style: TextStyle(
                    color: OrbitTokens.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pick one habit to keep visible on your home screen, '
                  'along with its own streak.',
                  style: TextStyle(
                    color: OrbitTokens.inkDim,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: habits.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Add a habit first to feature it here.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              _OptionTile(
                                icon: Icons.widgets_outlined,
                                title: 'None',
                                subtitle: 'Clear the widget selection',
                                selected: featuredId == null,
                                onTap: () => _select(context, null),
                              ),
                              const Divider(color: Colors.white12, height: 1),
                              ...habits.map(
                                (habit) => _OptionTile(
                                  icon: getIconFromCodePoint(
                                    habit.iconCodePoint,
                                  ),
                                  title: habit.title,
                                  subtitle:
                                      '${habit.computeCurrentStreak()} day streak',
                                  selected: habit.id == featuredId,
                                  onTap: () => _select(context, habit.id),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? OrbitTokens.teal.withValues(alpha: 0.2)
              : Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: selected ? OrbitTokens.teal : Colors.white54,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? OrbitTokens.teal : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: OrbitTokens.teal)
          : null,
    );
  }
}
