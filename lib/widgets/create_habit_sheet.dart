import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'common/premium_glass_card.dart';
import 'common/icon_picker_dialog.dart';
import '../providers/routine_provider.dart';
import '../models/habit.dart';
import '../utils/icon_utils.dart';
import '../theme/orbit_tokens.dart';
import '../services/ai_coach_service.dart';

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetCountController.dispose();
    _unitController.dispose();
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

        final habitData = {
          'title': title,
          'routine': _selectedRoutine,
          'iconCodePoint': _selectedIcon,
          'isGoal': _isGoal,
          // Unlike completedDays/totalDays/isCompleted above, this reflects
          // the *current* desired schedule on every save (create or edit)
          // -- there's no "reset to a stale default" risk here since it's
          // exactly what the day picker below shows the user right now.
          'activeDays': _activeDays,
          if (_selectedCategory != null) 'category': _selectedCategory,
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
              isCompleted: localIsCompleted,
              isGoal: _isGoal,
              category: _selectedCategory ?? existing?.category,
              activeDays: _activeDays,
              targetCount: targetCount,
              unit: unit.isNotEmpty ? unit : null,
              currentCount: localCurrentCount,
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
                          color: isSelected ? option.color : Colors.transparent,
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
                              color: isSelected ? Colors.white : Colors.white54,
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
            ),
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
