import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'common/premium_glass_card.dart';
import 'common/primary_button.dart';
import 'common/icon_picker_dialog.dart';
import '../providers/routine_provider.dart';
import '../models/habit.dart';
import '../utils/icon_utils.dart';
import '../theme/orbit_tokens.dart';
import '../services/ai_coach_service.dart';
import '../services/notification_service.dart';

class CreateHabitSheet extends StatefulWidget {
  final String? habitId;
  final String? initialTitle;
  final int? initialIcon;
  final String? initialRoutine; // ADDED THIS!
  final bool initialIsGoal;
  final String? initialCategory;
  final List<bool>? initialActiveDays;
  final int? initialTargetCount;
  final String? initialUnit;
  final bool initialRemindersEnabled;
  final String? initialReminderTime;
  final String? initialNote;
  final int? initialWeeklyTarget;

  const CreateHabitSheet({
    super.key,
    this.habitId,
    this.initialTitle,
    this.initialIcon,
    this.initialRoutine,
    this.initialIsGoal = false,
    this.initialCategory,
    this.initialActiveDays,
    this.initialTargetCount,
    this.initialUnit,
    this.initialRemindersEnabled = false,
    this.initialReminderTime,
    this.initialNote,
    this.initialWeeklyTarget,
  });

  static void show(
    BuildContext context, {
    String? habitId,
    String? initialTitle,
    int? initialIcon,
    String? initialRoutine,
    bool initialIsGoal = false,
    String? initialCategory,
    List<bool>? initialActiveDays,
    int? initialTargetCount,
    String? initialUnit,
    bool initialRemindersEnabled = false,
    String? initialReminderTime,
    String? initialNote,
    int? initialWeeklyTarget,
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
        initialIsGoal: initialIsGoal,
        initialCategory: initialCategory,
        initialActiveDays: initialActiveDays,
        initialTargetCount: initialTargetCount,
        initialUnit: initialUnit,
        initialRemindersEnabled: initialRemindersEnabled,
        initialReminderTime: initialReminderTime,
        initialNote: initialNote,
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
  late bool _isGoal;
  String? _selectedCategory;
  bool _isScanning = false;
  late List<bool> _activeDays;
  late bool _isCountBased;
  late TextEditingController _targetCountController;
  late TextEditingController _unitController;
  late bool _remindersEnabled;
  late TimeOfDay _reminderTime;
  late TextEditingController _noteController;
  late bool _isWeekly;
  late int _weeklyTarget;

  final Map<String, IconData> _routineIcons = {
    'Morning': Icons.wb_sunny_rounded,
    'Work': Icons.center_focus_strong_rounded,
    'Night': Icons.nightlight_round,
  };

  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // The 5 Focus Journey categories (StellarPlanetVariant.name -> label/icon/
  // color), matching the palette the Constellation Builder's stellar
  // planets already use for the same 5 variants.
  static const _categoryOptions = [
    (
      value: 'fitness',
      label: 'Fitness',
      icon: Icons.fitness_center_rounded,
      color: OrbitTokens.morning,
    ),
    (
      value: 'mind',
      label: 'Mind',
      icon: Icons.self_improvement_rounded,
      color: OrbitTokens.violet,
    ),
    (
      value: 'productivity',
      label: 'Productivity',
      icon: Icons.menu_book_rounded,
      color: OrbitTokens.teal,
    ),
    (
      value: 'growth',
      label: 'Growth',
      icon: Icons.explore_rounded,
      color: OrbitTokens.gold,
    ),
    (
      value: 'core',
      label: 'Core',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF3D5CFF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _selectedIcon = widget.initialIcon ?? Icons.star_rounded.codePoint;
    // Magic Fix: Safely default to passed routine or Morning!
    _selectedRoutine = widget.initialRoutine ?? 'Morning';
    _isGoal = widget.initialIsGoal;
    _selectedCategory = widget.initialCategory;
    _activeDays =
        widget.initialActiveDays != null &&
            widget.initialActiveDays!.length == 7
        ? List.of(widget.initialActiveDays!)
        : List.filled(7, true);
    _isCountBased = widget.initialTargetCount != null;
    _targetCountController = TextEditingController(
      text: (widget.initialTargetCount ?? 8).toString(),
    );
    _unitController = TextEditingController(text: widget.initialUnit ?? '');
    _noteController = TextEditingController(text: widget.initialNote ?? '');
    _isWeekly = widget.initialWeeklyTarget != null;
    _weeklyTarget = widget.initialWeeklyTarget ?? 3;
    _remindersEnabled = widget.initialRemindersEnabled;
    _reminderTime = _parseReminderTime(widget.initialReminderTime);
  }

  static TimeOfDay _parseReminderTime(String? value) {
    final parts = value?.split(':');
    if (parts == null || parts.length != 2) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetCountController.dispose();
    _unitController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Widget _repeatModeChip(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00E5FF)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF00E5FF) : Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _weeklyStepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
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
        //
        // This is used for both create AND edit (widget.habitId != null).
        // completedDays/totalDays/isCompleted/color used to be hardcoded to
        // their initial values unconditionally -- SetOptions(merge: true)
        // only *preserves* keys absent from the write, so every edit (even
        // just renaming a habit) silently zeroed the real Firestore
        // completedDays/totalDays/isCompleted. upsertHabitLocally() patched
        // the correct values back into local state, masking this in the UI
        // right up until the next full reload from Firestore, at which
        // point the real progress was gone. Only set them on create.
        final targetCount = _isCountBased
            ? (int.tryParse(_targetCountController.text.trim()) ?? 8).clamp(
                1,
                9999,
              )
            : null;
        final unit = _unitController.text.trim();
        final note = _noteController.text.trim();
        final reminderTimeStr = _remindersEnabled
            ? '${_reminderTime.hour.toString().padLeft(2, '0')}:'
                  '${_reminderTime.minute.toString().padLeft(2, '0')}'
            : null;

        final habitData = {
          'title': title,
          'routine': _selectedRoutine,
          'iconCodePoint': _selectedIcon,
          'isGoal': _isGoal,
          // Unlike completedDays/totalDays/isCompleted above, this reflects
          // the *current* desired schedule on every save (create or edit)
          // -- there's no "reset to a stale default" risk here since it's
          // exactly what the day picker below shows the user right now.
          // Weekly ("N times/week") habits are available to log every day.
          'activeDays': _isWeekly ? List.filled(7, true) : _activeDays,
          'remindersEnabled': _remindersEnabled,
          if (reminderTimeStr != null)
            'reminderTime': reminderTimeStr
          else
            // Explicit clear, not just omit -- merge writes only ever
            // *preserve* keys absent from the payload (same reasoning as
            // targetCount/unit below).
            'reminderTime': FieldValue.delete(),
          if (_selectedCategory != null) 'category': _selectedCategory,
          // Optional motivation note -- explicit clear on empty (merge writes
          // only preserve absent keys), same pattern as reminderTime above.
          if (note.isNotEmpty) 'note': note else 'note': FieldValue.delete(),
          // Flexible weekly scheduling -- explicit clear when switched off.
          if (_isWeekly)
            'weeklyTarget': _weeklyTarget
          else
            'weeklyTarget': FieldValue.delete(),
          if (widget.habitId == null) ...{
            'completedDays': 0,
            'totalDays': 0,
            'color': 0xFF00E5FF,
            'isCompleted': false,
          },
          if (targetCount != null) ...{
            'targetCount': targetCount,
            if (unit.isNotEmpty) 'unit': unit,
          } else if (widget.habitId != null) ...{
            // Switched a previously count-based habit back to simple --
            // explicitly clear, not just omit (merge writes only ever
            // *preserve* keys absent from the payload).
            'targetCount': FieldValue.delete(),
            'unit': FieldValue.delete(),
            'currentCount': FieldValue.delete(),
          },
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
          // Re-derive isCompleted from currentCount vs targetCount when
          // count-based, so switching a habit's type mid-day keeps the
          // isCompleted invariant consistent (e.g. turning tracking on for
          // an already-checked-off habit starts it back at not-done until
          // the target is actually hit).
          final localCurrentCount = targetCount != null
              ? (existing?.currentCount ?? 0)
              : 0;
          final localIsCompleted = targetCount != null
              ? localCurrentCount >= targetCount
              : (existing?.isCompleted ?? false);
          final localHabit = Habit(
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
            isCompleted: localIsCompleted,
            isGoal: _isGoal,
            category: _selectedCategory ?? existing?.category,
            activeDays: _isWeekly ? List.filled(7, true) : _activeDays,
            weeklyTarget: _isWeekly ? _weeklyTarget : null,
            targetCount: targetCount,
            unit: unit.isNotEmpty ? unit : null,
            currentCount: localCurrentCount,
            history: existing?.history,
            remindersEnabled: _remindersEnabled,
            reminderTime: reminderTimeStr,
            note: note.isNotEmpty ? note : null,
          );
          // Best-effort -- a permission/scheduling failure shouldn't block
          // saving the habit itself (matches _safeZonedSchedule's own
          // swallow-and-log behavior for routine alarms). Gated on the
          // Settings > "Enable All Notifications" master toggle -- when
          // it's off, the habit's own remindersEnabled stays saved so
          // setAllNotifsEnabled(true) can reschedule it later, but it
          // shouldn't start firing the moment it's created.
          if (provider.allNotifsEnabled) {
            NotificationService.scheduleHabitReminder(localHabit);
          }
          provider.upsertHabitLocally(docId, localHabit);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error creating habit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save habit. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Moved here from a standalone home-screen FAB (AiLensButton) — a second
  // permanently-shimmering FAB competing with "New Habit" for attention on
  // the busiest screen in the app wasn't worth it for a feature people
  // reach for occasionally. This sheet is where every habit gets created
  // regardless of entry point, so it's just as discoverable here.
  Future<void> _scanWithAiLens() async {
    HapticFeedback.heavyImpact();
    final picker = ImagePicker();
    XFile? image;
    try {
      image = await picker.pickImage(source: ImageSource.camera);
    } catch (e) {
      debugPrint('AI Lens: camera unavailable: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Camera unavailable.')));
      }
      return;
    }
    if (image == null) return;

    setState(() => _isScanning = true);
    try {
      final aiSuggestion = await AiCoachService.analyzeImageForHabit(image);
      const Map<String, IconData> availableIcons = {
        'Explore': Icons.explore_rounded,
        'Fitness': Icons.fitness_center_rounded,
        'Book': Icons.menu_book_rounded,
        'Mind': Icons.self_improvement_rounded,
        'Sun': Icons.wb_sunny_rounded,
        'Moon': Icons.nightlight_round,
        'Work': Icons.work_rounded,
        'Heart': Icons.favorite_rounded,
      };
      final iconCodePoint =
          (availableIcons[aiSuggestion['icon']] ?? Icons.explore_rounded)
              .codePoint;
      if (mounted) {
        setState(() {
          _titleController.text =
              aiSuggestion['title'] ?? _titleController.text;
          _selectedIcon = iconCodePoint;
        });
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
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
        // Scrollable so the full form (plus the IGNITE button) never overflows
        // when the keyboard is up on shorter devices -- previously the fixed
        // Column ran ~30px past the sheet's height, tripping a RenderFlex
        // overflow right on the primary action button.
        child: SingleChildScrollView(
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
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: _isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF7000FF),
                                ),
                              )
                            : const Icon(
                                Icons.document_scanner_rounded,
                                color: Color(0xFF7000FF),
                              ),
                        tooltip: 'Scan with AI Lens',
                        onPressed: _isScanning ? null : _scanWithAiLens,
                      ),
                      IconButton(
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
                    ],
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
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
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
              const SizedBox(height: 24),
              Text(
                widget.habitId == null
                    ? "Focus Journey (optional)"
                    : "Focus Journey (set at creation)",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: widget.habitId == null ? 1.0 : 0.5,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categoryOptions.map((option) {
                    final isSelected = _selectedCategory == option.value;
                    return GestureDetector(
                      // categoryCompletions() sums a habit's *entire* history
                      // of completedDays under whatever category it's
                      // currently tagged with -- re-tagging an already
                      // long-running habit retroactively moved its whole
                      // completion count into the new category, which could
                      // instantly max out (25 completions unlocks all 5
                      // chapters + 150 XP) a Focus Journey the user never
                      // actually did any work in. Category is create-time only.
                      onTap: widget.habitId != null
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedCategory = isSelected
                                    ? null
                                    : option.value;
                              });
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? option.color.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: isSelected
                                ? option.color
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              option.icon,
                              color: isSelected ? option.color : Colors.white54,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              option.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Repeats",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Mode toggle: specific weekdays vs. a flexible "N times / week".
              Row(
                children: [
                  _repeatModeChip('Specific days', !_isWeekly,
                      () => setState(() => _isWeekly = false)),
                  const SizedBox(width: 8),
                  _repeatModeChip('Times / week', _isWeekly,
                      () => setState(() => _isWeekly = true)),
                ],
              ),
              const SizedBox(height: 14),
              if (!_isWeekly)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (dayIndex) {
                    final isActive = _activeDays[dayIndex];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        // A habit due on zero days makes no sense (it would
                        // never be tallied and could never advance a streak) --
                        // keep at least one day active, same guard used
                        // elsewhere in the app for alarm day toggles.
                        final activeCount = _activeDays.where((d) => d).length;
                        if (isActive && activeCount <= 1) return;
                        setState(() => _activeDays[dayIndex] = !isActive);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF00E5FF)
                              : Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF00E5FF)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _weekdayLabels[dayIndex],
                          style: TextStyle(
                            color: isActive ? Colors.black : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }),
                )
              else
                Row(
                  children: [
                    _weeklyStepButton(Icons.remove_rounded, () {
                      if (_weeklyTarget > 1) {
                        setState(() => _weeklyTarget--);
                      }
                    }),
                    Expanded(
                      child: Text(
                        '$_weeklyTarget× per week',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _weeklyStepButton(Icons.add_rounded, () {
                      if (_weeklyTarget < 7) {
                        setState(() => _weeklyTarget++);
                      }
                    }),
                  ],
                ),
              if (_isWeekly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Complete it any $_weeklyTarget days each week — rest days '
                    "won't break your streak.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _remindersEnabled,
                activeThumbColor: const Color(0xFF00E5FF),
                title: const Text(
                  'Remind Me',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Get a nudge for just this habit, separate from your routine alarms.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _remindersEnabled = val);
                },
              ),
              if (_remindersEnabled) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _reminderTime,
                    );
                    if (picked != null) {
                      setState(() => _reminderTime = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.alarm_rounded,
                          color: Color(0xFF00E5FF),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _reminderTime.format(context),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isCountBased,
                activeThumbColor: const Color(0xFF00E5FF),
                title: const Text(
                  'Track a Number',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'For habits like "Drink 8 glasses of water" instead of a simple checkbox.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _isCountBased = val);
                },
              ),
              if (_isCountBased) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _targetCountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Daily target',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _unitController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Unit (glasses, pages...)',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isGoal,
                activeThumbColor: const Color(0xFF00E5FF),
                title: const Text(
                  'Mark as Goal',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Goal habits show a badge to help them stand out.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _isGoal = val);
                },
              ),
              const SizedBox(height: 16),
              // Optional motivation note ("why this matters to me").
              TextField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 500,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Your "why" (optional)',
                  labelStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  hintText: 'Why does this habit matter to you?',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  counterStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  prefixIcon: Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                text: 'IGNITE',
                isLoading: _isLoading,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _createHabit();
                },
              ),
            ],
          ),
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
