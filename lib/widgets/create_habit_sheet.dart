import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'common/premium_glass_card.dart';
import 'common/icon_picker_dialog.dart';
import '../providers/routine_provider.dart';
import '../models/habit.dart';
import '../utils/icon_utils.dart';

class CreateHabitSheet extends StatefulWidget {
  final String? habitId;
  final String? initialTitle;
  final int? initialIcon;
  final String? initialRoutine; // ADDED THIS!

  const CreateHabitSheet({
    super.key,
    this.habitId,
    this.initialTitle,
    this.initialIcon,
    this.initialRoutine,
  });

  static void show(
    BuildContext context, {
    String? habitId,
    String? initialTitle,
    int? initialIcon,
    String? initialRoutine,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateHabitSheet(
        habitId: habitId,
        initialTitle: initialTitle,
        initialIcon: initialIcon,
        initialRoutine: initialRoutine,
      ),
    );
  }

  @override
  State<CreateHabitSheet> createState() => _CreateHabitSheetState();
}

class _CreateHabitSheetState extends State<CreateHabitSheet> {
  late TextEditingController _titleController;
  bool _isLoading = false;
  late String _selectedRoutine;
  late int _selectedIcon;

  final Map<String, IconData> _routineIcons = {
    'Morning': Icons.wb_sunny_rounded,
    'Work': Icons.center_focus_strong_rounded,
    'Night': Icons.nightlight_round,
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _selectedIcon = widget.initialIcon ?? Icons.star_rounded.codePoint;
    // Magic Fix: Safely default to passed routine or Morning!
    _selectedRoutine = widget.initialRoutine ?? 'Morning';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createHabit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docId =
            widget.habitId ??
            title.toLowerCase().replaceAll(' ', '_') +
                DateTime.now().millisecondsSinceEpoch.toString();

        // Keys must match firestore.rules' isValidHabit() allowlist exactly
        // (which mirrors Habit.toMap()) — a 'createdAt' field here used to
        // get every write rejected with PERMISSION_DENIED, silently, since
        // the failure was only ever debugPrint'd.
        final habitData = {
          'title': title,
          'routine': _selectedRoutine,
          'iconCodePoint': _selectedIcon,
          'completedDays': 0,
          'totalDays': 0,
          'color': 0xFF00E5FF,
          'isCompleted': false,
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('habits')
            .doc(docId)
            .set(habitData, SetOptions(merge: true));

        // Update the provider's local state immediately so the UI reflects
        // the change without waiting for the next cold app load.
        // CreateHabitSheet writes directly to Firestore (bypassing
        // RoutineProvider.addHabit) so we must sync local state here.
        if (mounted) {
          final provider = context.read<RoutineProvider>();
          final existing = provider.habits[docId];
          provider.upsertHabitLocally(
            docId,
            Habit(
              id: docId,
              title: title,
              routineType: _selectedRoutine,
              iconCodePoint: _selectedIcon,
              color: 0xFF00E5FF,
              completedDays: existing?.completedDays ?? 0,
              totalDays: existing?.totalDays ?? 0,
              order:
                  existing?.order ??
                  provider.getHabitsForRoutine(_selectedRoutine).length,
              isCompleted: existing?.isCompleted ?? false,
              history: existing?.history,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error creating habit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save habit. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: PremiumGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Text(
                widget.habitId == null ? 'Launch New Habit' : 'Edit Habit',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'e.g. Drink 1L Water',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                prefixIcon: Icon(
                  Icons.star_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    getIconFromCodePoint(_selectedIcon),
                    color: const Color(0xFF00E5FF),
                  ),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final pickedIcon = await IconPickerDialog.show(
                      context,
                      _selectedIcon,
                    );
                    if (pickedIcon != null) {
                      setState(() => _selectedIcon = pickedIcon);
                    }
                  },
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Assign to Routine",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _routineIcons.entries.map((entry) {
                final isSelected = _selectedRoutine == entry.key;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedRoutine = entry.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00E5FF)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            entry.value,
                            color: isSelected
                                ? const Color(0xFF00E5FF)
                                : Colors.white54,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.key,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      _createHabit();
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'IGNITE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ).animate().slideY(
      begin: 0.2,
      end: 0,
      duration: 400.ms,
      curve: Curves.easeOutQuart,
    );
  }
}
