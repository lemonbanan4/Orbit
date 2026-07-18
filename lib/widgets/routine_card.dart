// lib/widgets/routine_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/routine_provider.dart';
import '../providers/ai_fairy_provider.dart';
import '../providers/telemetry_provider.dart';
import '../providers/atmosphere_provider.dart';
import 'reward_popup.dart';
import 'telemetry_levelup_dialog.dart';
import 'create_habit_sheet.dart';
import 'manage_habit_dialog.dart';
import '../screens/coaching/routine_detail_screen.dart';
import '../models/habit.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../utils/icon_utils.dart';
import '../theme/orbit_colors.dart';

class RoutineCard extends StatefulWidget {
  final String title;
  final String time;
  final String sessionType;
  //final List<Map<String, dynamic>> habits;
  final List<Habit> habits;
  final List<Color> gradientColors;
  final Function(int, int) onReorder;
  final Function(String) onDeleteHabit;
  final VoidCallback onSkipRoutine;
  final VoidCallback onAddHabit;
  final VoidCallback onTimeTapped;
  final bool enableBlur;
  final String? highlightHabit;

  const RoutineCard({
    super.key,
    required this.title,
    required this.time,
    required this.sessionType,
    required this.habits,
    required this.gradientColors,
    required this.onReorder,
    required this.onDeleteHabit,
    required this.onSkipRoutine,
    required this.onAddHabit,
    required this.onTimeTapped,
    this.enableBlur = true,
    this.highlightHabit,
  });

  @override
  State<RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<RoutineCard> {
  final Set<String> _deletingIds = {};
  String? _lastScrolledHighlight;
  // Starts compact — the pitch's dashboard shows routines as slim summary
  // rows (time, accent stripe, "x/y done"), with the full habit checklist
  // living one tap away. _loadExpandedState() below overrides this with
  // whatever the user last chose per routine, so this only affects the
  // very first time a routine card is ever shown.
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadExpandedState();
  }

  Future<void> _loadExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isExpanded =
            prefs.getBool('routine_expanded_${widget.sessionType}') ?? true;
      });
    }
  }

  Future<void> _toggleExpanded() async {
    setState(() => _isExpanded = !_isExpanded);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('routine_expanded_${widget.sessionType}', _isExpanded);
  }

  @override
  void didUpdateWidget(RoutineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightHabit != oldWidget.highlightHabit) {
      _lastScrolledHighlight =
          null; // Reset so we can scroll again if it changes
    }
  }

  IconData _getHeaderIcon() {
    if (widget.sessionType.toLowerCase() == 'morning') {
      return Icons.wb_sunny_rounded;
    }
    if (widget.sessionType.toLowerCase() == 'work' ||
        widget.sessionType.toLowerCase() == 'workday') {
      return Icons.fitness_center_rounded;
    }
    return Icons.nightlight_round;
  }

  @override
  Widget build(BuildContext context) {
    final int completedCount = widget.habits.where((h) => h.isCompleted).length;
    final int totalCount = widget.habits.length;
    final double progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    // Theme's actual brand accent (orange in dark mode, cyan in light) —
    // used for habit-level chrome that isn't tied to this routine's own
    // identity color (edit/highlight/drag states, not the routine itself).
    final Color themeAccent =
        Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- LEFT COLUMN: THE CLOCK TIME INDEX ---
          SizedBox(
            width: 55,
            child: Column(
              children: [
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: widget.onTimeTapped,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.time,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- RIGHT COLUMN: THE COMPACT LIQUID GLASS CARD CORE ---
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: widget.enableBlur ? 20.0 : 0.0,
                  sigmaY: widget.enableBlur ? 20.0 : 0.0,
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // INTERACTIVE GRADIENT CARD HEADER
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              transitionDuration: const Duration(
                                milliseconds: 400,
                              ),
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      RoutineDetailScreen(
                                        routineTitle: widget.title,
                                        sessionType: widget.sessionType,
                                        gradientColors: widget.gradientColors,
                                        time: widget.time,
                                      ),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position:
                                            Tween<Offset>(
                                              begin: const Offset(0, 0.05),
                                              end: Offset.zero,
                                            ).animate(
                                              CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOutCubic,
                                              ),
                                            ),
                                        child: child,
                                      ),
                                    );
                                  },
                            ),
                          );
                        },
                        child: Hero(
                          tag: 'routine_gradient_${widget.sessionType}',
                          flightShuttleBuilder:
                              (
                                flightContext,
                                animation,
                                flightDirection,
                                fromHeroContext,
                                toHeroContext,
                              ) {
                                final fromWidget =
                                    (fromHeroContext.widget as Hero).child;
                                final toWidget =
                                    (toHeroContext.widget as Hero).child;
                                return Material(
                                  color: Colors.transparent,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      FadeTransition(
                                        opacity: Tween<double>(
                                          begin: 1.0,
                                          end: 0.0,
                                        ).animate(animation),
                                        child: fromWidget,
                                      ),
                                      FadeTransition(
                                        opacity: animation,
                                        child: toWidget,
                                      ),
                                      AnimatedBuilder(
                                        animation: animation,
                                        builder: (context, child) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    24 * (1 - animation.value),
                                                  ),
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha:
                                                        0.6 *
                                                        math.sin(
                                                          animation.value *
                                                              math.pi,
                                                        ),
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.0,
                                                  ),
                                                ],
                                                begin: Alignment(
                                                  -2.0 + (animation.value * 3),
                                                  -1.0,
                                                ),
                                                end: Alignment(
                                                  -1.0 + (animation.value * 3),
                                                  1.0,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: widget.gradientColors.first
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getHeaderIcon(),
                                    color: widget.gradientColors.first,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              "TODAY",
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ),
                                          if (totalCount > 0) ...[
                                            const SizedBox(width: 8),
                                            // Flexible + compact "x/y done"
                                            // so the row can never overflow —
                                            // the long "N / M completed" text
                                            // overflowed by ~15px once the
                                            // completion circle joined the
                                            // header.
                                            Flexible(
                                              child: AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                transitionBuilder:
                                                    (child, animation) =>
                                                        SlideTransition(
                                                          position:
                                                              Tween<Offset>(
                                                                begin:
                                                                    const Offset(
                                                                      0,
                                                                      -0.5,
                                                                    ),
                                                                end: Offset
                                                                    .zero,
                                                              ).animate(
                                                                animation,
                                                              ),
                                                          child: FadeTransition(
                                                            opacity: animation,
                                                            child: child,
                                                          ),
                                                        ),
                                                child: Text(
                                                  '$completedCount/$totalCount done',
                                                  key: ValueKey<int>(
                                                    completedCount,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.7),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Mock-style completion state: filled check
                                // once every habit in the routine is done,
                                // quiet outline until then.
                                Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        totalCount > 0 &&
                                            completedCount == totalCount
                                        ? widget.gradientColors.first
                                              .withValues(alpha: 0.25)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color:
                                          totalCount > 0 &&
                                              completedCount == totalCount
                                          ? widget.gradientColors.first
                                          : Colors.white24,
                                      width: 1.5,
                                    ),
                                  ),
                                  child:
                                      totalCount > 0 &&
                                          completedCount == totalCount
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: widget.gradientColors.first,
                                        )
                                      : null,
                                ),
                                GestureDetector(
                                  onTap: _toggleExpanded,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                      vertical: 4.0,
                                    ),
                                    child: Icon(
                                      _isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white54,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: !_isExpanded
                            ? const SizedBox(width: double.infinity)
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // LINEAR PROGRESS BAR
                                  if (totalCount > 0)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20.0,
                                        vertical: 12.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'ROUTINE PROGRESS',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.5),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                              Text(
                                                '${(progress * 100).toInt()}%',
                                                style: TextStyle(
                                                  color: widget
                                                      .gradientColors
                                                      .first,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: TweenAnimationBuilder<double>(
                                              tween: Tween<double>(
                                                begin: 0,
                                                end: progress,
                                              ),
                                              duration: const Duration(
                                                milliseconds: 500,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              builder: (context, value, _) {
                                                return LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    return Stack(
                                                      children: [
                                                        // 1. Static Background Track
                                                        Container(
                                                          height: 6,
                                                          width: constraints
                                                              .maxWidth,
                                                          decoration: BoxDecoration(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.05,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                        ),

                                                        // 2. Drifting Stardust Particles
                                                        Positioned.fill(
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                            child: Stack(
                                                              children: List.generate(5, (
                                                                i,
                                                              ) {
                                                                return Positioned(
                                                                  top: 2,
                                                                  left: 0,
                                                                  child:
                                                                      Container(
                                                                            width:
                                                                                2,
                                                                            height:
                                                                                2,
                                                                            decoration: BoxDecoration(
                                                                              color: widget.gradientColors.last.withValues(
                                                                                alpha: 0.6,
                                                                              ),
                                                                              shape: BoxShape.circle,
                                                                            ),
                                                                          )
                                                                          .animate(
                                                                            onPlay: (c) =>
                                                                                c.repeat(),
                                                                            delay: Duration(
                                                                              milliseconds:
                                                                                  i *
                                                                                  800,
                                                                            ),
                                                                          )
                                                                          .moveX(
                                                                            begin:
                                                                                constraints.maxWidth,
                                                                            end:
                                                                                -10,
                                                                            duration: const Duration(
                                                                              milliseconds: 4000,
                                                                            ),
                                                                            curve:
                                                                                Curves.linear,
                                                                          )
                                                                          .fadeIn(
                                                                            duration:
                                                                                400.ms,
                                                                          )
                                                                          .fadeOut(
                                                                            delay:
                                                                                3200.ms,
                                                                            duration:
                                                                                400.ms,
                                                                          ),
                                                                );
                                                              }),
                                                            ),
                                                          ),
                                                        ),

                                                        // 3. Foreground Completed Gradient
                                                        Container(
                                                              height: 6,
                                                              width:
                                                                  constraints
                                                                      .maxWidth *
                                                                  value,
                                                              decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                  colors: widget
                                                                      .gradientColors,
                                                                  begin: Alignment
                                                                      .centerLeft,
                                                                  end: Alignment
                                                                      .centerRight,
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                              ),
                                                            )
                                                            .animate(
                                                              onPlay:
                                                                  (
                                                                    controller,
                                                                  ) => controller
                                                                      .repeat(),
                                                            )
                                                            .shimmer(
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        2500,
                                                                  ),
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.3,
                                                                  ),
                                                              angle:
                                                                  math.pi / 4,
                                                            ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // INTERNAL INNER HABITS ROW SECTOR
                                  if (widget.habits.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 24.0,
                                        horizontal: 16.0,
                                      ),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.auto_awesome,
                                              color: Colors.white24,
                                              size: 28,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              "The cosmos is quiet... for now.",
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.8,
                                                ),
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            TextButton.icon(
                                              onPressed: widget.onAddHabit,
                                              icon: Icon(
                                                Icons.add,
                                                size: 14,
                                                color: themeAccent,
                                              ),
                                              label: Text(
                                                "Add a habit",
                                                style: TextStyle(
                                                  color: themeAccent,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Material(
                                      type: MaterialType.transparency,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 240,
                                        ),
                                        child: ReorderableListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const ClampingScrollPhysics(),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          buildDefaultDragHandles: false,
                                          itemCount: widget.habits.length,
                                          onReorderItem: (oldIndex, newIndex) {
                                            widget.onReorder(
                                              oldIndex,
                                              newIndex,
                                            );
                                          },
                                          onReorderStart: (index) {
                                            HapticFeedback.lightImpact();
                                            try {
                                              AudioPlayer().play(
                                                AssetSource('audio/click.mp3'),
                                              );
                                            } catch (e) {
                                              debugPrint(
                                                'Error playing click sound: $e',
                                              );
                                            }
                                            Future.delayed(
                                              const Duration(milliseconds: 100),
                                              () =>
                                                  HapticFeedback.lightImpact(),
                                            );
                                          },
                                          onReorderEnd: (index) {
                                            HapticFeedback.heavyImpact();
                                          },
                                          proxyDecorator:
                                              (child, index, animation) {
                                                return Material(
                                                  color: Colors.transparent,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF1F1235,
                                                      ).withValues(alpha: 0.9),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: themeAccent
                                                              .withValues(
                                                                alpha: 0.25,
                                                              ),
                                                          blurRadius: 15,
                                                          spreadRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                    child: child,
                                                  ),
                                                );
                                              },
                                          itemBuilder: (context, index) {
                                            final habit = widget.habits[index];
                                            final bool isCompleted =
                                                habit.isCompleted;
                                            final Color highlightColor =
                                                themeAccent;
                                            final bool isDeleting = _deletingIds
                                                .contains(habit.id);
                                            final bool isRestored = context
                                                .read<RoutineProvider>()
                                                .recentlyRestoredHabitIds
                                                .contains(habit.id);
                                            final bool isHighlighted =
                                                widget.highlightHabit != null &&
                                                widget.highlightHabit ==
                                                    habit.title;

                                            Widget content = AnimatedOpacity(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              opacity: isDeleting ? 0.0 : 1.0,
                                              child: AnimatedSize(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                curve: Curves.easeInOutBack,
                                                child: isDeleting
                                                    ? const SizedBox(
                                                        width: double.infinity,
                                                        height: 0,
                                                      )
                                                    : Slidable(
                                                        key: ValueKey(
                                                          'slidable_${habit.id}',
                                                        ),
                                                        endActionPane: ActionPane(
                                                          motion:
                                                              const DrawerMotion(),
                                                          extentRatio: 0.45,
                                                          children: [
                                                            SlidableAction(
                                                              onPressed: (actionContext) {
                                                                HapticFeedback.lightImpact();
                                                                CreateHabitSheet.show(
                                                                  context,
                                                                  habitId:
                                                                      habit.id,
                                                                  initialTitle:
                                                                      habit
                                                                          .title,
                                                                  initialRoutine:
                                                                      widget
                                                                          .sessionType,
                                                                  initialIcon: habit
                                                                      .iconCodePoint,
                                                                  initialIsGoal:
                                                                      habit.isGoal,
                                                                  initialCategory:
                                                                      habit.category,
                                                                );
                                                              },
                                                              backgroundColor:
                                                                  const Color(
                                                                    0xFF1F1235,
                                                                  ),
                                                              foregroundColor:
                                                                  themeAccent,
                                                              icon: Icons
                                                                  .edit_outlined,
                                                              label: 'Edit',
                                                            ),
                                                            SlidableAction(
                                                              onPressed: (actionContext) async {
                                                                HapticFeedback.heavyImpact();
                                                                final bool?
                                                                confirm = await ManageHabitDialog.show(
                                                                  context,
                                                                  habitId:
                                                                      habit.id,
                                                                  habitTitle:
                                                                      habit
                                                                          .title,
                                                                  sessionType:
                                                                      widget
                                                                          .sessionType,
                                                                  iconCodePoint:
                                                                      habit
                                                                          .iconCodePoint,
                                                                  onDelete:
                                                                      () {},
                                                                );
                                                                if (confirm ==
                                                                    true) {
                                                                  setState(() {
                                                                    _deletingIds
                                                                        .add(
                                                                          habit
                                                                              .id,
                                                                        );
                                                                  });
                                                                  await Future.delayed(
                                                                    const Duration(
                                                                      milliseconds:
                                                                          300,
                                                                    ),
                                                                  );
                                                                  if (!context
                                                                      .mounted) {
                                                                    return;
                                                                  }
                                                                  widget
                                                                      .onDeleteHabit(
                                                                        habit
                                                                            .id,
                                                                      );
                                                                  setState(() {
                                                                    _deletingIds
                                                                        .remove(
                                                                          habit
                                                                              .id,
                                                                        );
                                                                  });
                                                                }
                                                              },
                                                              backgroundColor:
                                                                  Colors
                                                                      .redAccent
                                                                      .withValues(
                                                                        alpha:
                                                                            0.8,
                                                                      ),
                                                              foregroundColor:
                                                                  Colors.white,
                                                              icon: Icons
                                                                  .delete_outline_rounded,
                                                              label: 'Delete',
                                                              borderRadius:
                                                                  const BorderRadius.horizontal(
                                                                    right:
                                                                        Radius.circular(
                                                                          12,
                                                                        ),
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: ListTile(
                                                          contentPadding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 20,
                                                                vertical: 2,
                                                              ),
                                                          leading: Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: isCompleted
                                                                  ? Colors
                                                                        .white10
                                                                  : highlightColor
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                            child: Icon(
                                                              getIconFromCodePoint(
                                                                habit
                                                                    .iconCodePoint,
                                                              ),
                                                              color: isCompleted
                                                                  ? Colors
                                                                        .white30
                                                                  : highlightColor,
                                                              size: 20,
                                                            ),
                                                          ),
                                                          title: Text(
                                                            habit.title,
                                                            style: TextStyle(
                                                              color: isCompleted
                                                                  ? Colors
                                                                        .white54
                                                                  : Colors
                                                                        .white,
                                                              decoration:
                                                                  isCompleted
                                                                  ? TextDecoration
                                                                        .lineThrough
                                                                  : null,
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                            maxLines: null,
                                                            softWrap: true,
                                                          ),
                                                          trailing: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              GestureDetector(
                                                                onTap: () async {
                                                                  final routineProvider =
                                                                      context
                                                                          .read<
                                                                            RoutineProvider
                                                                          >();
                                                                  final bool
                                                                  wasCompleted =
                                                                      habit
                                                                          .isCompleted;
                                                                  final int
                                                                  skips = habit
                                                                      .skippedCount;
                                                                  await routineProvider
                                                                      .toggleHabit(
                                                                        habit
                                                                            .id,
                                                                      );

                                                                  // Clear active notifications if all daily habits are now completed
                                                                  final allCompleted =
                                                                      routineProvider
                                                                          .habits
                                                                          .values
                                                                          .isNotEmpty &&
                                                                      routineProvider
                                                                          .habits
                                                                          .values
                                                                          .every(
                                                                            (
                                                                              h,
                                                                            ) =>
                                                                                h.isCompleted,
                                                                          );
                                                                  if (allCompleted) {
                                                                    await NotificationService.clearActiveRoutineReminders();
                                                                  }

                                                                  if (!context
                                                                      .mounted) {
                                                                    return;
                                                                  }

                                                                  if (!wasCompleted) {
                                                                    HapticFeedback.lightImpact();
                                                                    context
                                                                        .read<
                                                                          AIFairyProvider
                                                                        >()
                                                                        .cheerForHabit(
                                                                          habit
                                                                              .title,
                                                                          routineProvider
                                                                              .currentStreak,
                                                                          playSound:
                                                                              routineProvider.soundsEnabled,
                                                                          skippedCount:
                                                                              skips,
                                                                        );

                                                                    context
                                                                        .read<
                                                                          AtmosphereProvider
                                                                        >()
                                                                        .setAura(
                                                                          AtmosphereProvider.auraForHabitCompletion(
                                                                            streak:
                                                                                routineProvider.currentStreak,
                                                                            skippedCount:
                                                                                skips,
                                                                          ),
                                                                        );

                                                                    final telemetry =
                                                                        context
                                                                            .read<
                                                                              TelemetryProvider
                                                                            >();
                                                                    bool
                                                                    didLevelUp =
                                                                        await telemetry
                                                                            .awardXp(
                                                                              15,
                                                                            );

                                                                    if (!context
                                                                        .mounted) {
                                                                      return;
                                                                    }

                                                                    // Check for Milestone Unlocks
                                                                    final newMilestones =
                                                                        telemetry.checkMilestoneUnlocks(
                                                                          routineProvider
                                                                              .currentStreak,
                                                                        );
                                                                    if (newMilestones
                                                                        .isNotEmpty) {
                                                                      final thresholds =
                                                                          [
                                                                            3,
                                                                            7,
                                                                            14,
                                                                            21,
                                                                            30,
                                                                            45,
                                                                            60,
                                                                            90,
                                                                            120,
                                                                            150,
                                                                            180,
                                                                            210,
                                                                            250,
                                                                            300,
                                                                            365,
                                                                          ];
                                                                      final days =
                                                                          thresholds[newMilestones
                                                                              .first];

                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        SnackBar(
                                                                          content: Row(
                                                                            children: [
                                                                              const Icon(
                                                                                Icons.emoji_events_rounded,
                                                                                color: Color(
                                                                                  0xFFFFD700,
                                                                                ),
                                                                                size: 28,
                                                                              ),
                                                                              const SizedBox(
                                                                                width: 12,
                                                                              ),
                                                                              Expanded(
                                                                                child: Column(
                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                                  children: [
                                                                                    const Text(
                                                                                      "MILESTONE UNLOCKED",
                                                                                      style: TextStyle(
                                                                                        fontWeight: FontWeight.w900,
                                                                                        fontSize: 12,
                                                                                        letterSpacing: 1.2,
                                                                                        color: Color(
                                                                                          0xFFFFD700,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                    Text(
                                                                                      "$days Day Streak Achieved!",
                                                                                      style: const TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontSize: 14,
                                                                                        fontWeight: FontWeight.bold,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          backgroundColor: const Color(
                                                                            0xFF1F1235,
                                                                          ),
                                                                          behavior:
                                                                              SnackBarBehavior.floating,
                                                                          shape: RoundedRectangleBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              16,
                                                                            ),
                                                                            side: BorderSide(
                                                                              color:
                                                                                  const Color(
                                                                                    0xFFFFD700,
                                                                                  ).withValues(
                                                                                    alpha: 0.5,
                                                                                  ),
                                                                              width: 1.5,
                                                                            ),
                                                                          ),
                                                                          margin: const EdgeInsets.only(
                                                                            bottom:
                                                                                24,
                                                                            left:
                                                                                24,
                                                                            right:
                                                                                24,
                                                                          ),
                                                                          duration: const Duration(
                                                                            seconds:
                                                                                4,
                                                                          ),
                                                                        ),
                                                                      );
                                                                    }

                                                                    if (didLevelUp) {
                                                                      TelemetryLevelUpDialog.show(
                                                                        context,
                                                                        telemetry
                                                                            .currentLevel,
                                                                        habitTitle:
                                                                            habit.title,
                                                                      );
                                                                    } else if (context
                                                                        .mounted) {
                                                                      RewardPopup.show(
                                                                        context,
                                                                        title:
                                                                            "Habit Completed!",
                                                                        xpEarned:
                                                                            15,
                                                                        currentTotalXp:
                                                                            telemetry.globalXp,
                                                                      );
                                                                    }
                                                                  }
                                                                },
                                                                child: AnimatedContainer(
                                                                  duration:
                                                                      const Duration(
                                                                        milliseconds:
                                                                            200,
                                                                      ),
                                                                  width: 24,
                                                                  height: 24,
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        isCompleted
                                                                        ? themeAccent
                                                                        : Colors
                                                                              .transparent,
                                                                    border: Border.all(
                                                                      color:
                                                                          isCompleted
                                                                          ? themeAccent
                                                                          : Colors.white.withValues(
                                                                              alpha: 0.8,
                                                                            ),
                                                                      width: 2,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          6,
                                                                        ),
                                                                  ),
                                                                  child:
                                                                      isCompleted
                                                                      ? const Icon(
                                                                          Icons
                                                                              .check_rounded,
                                                                          color:
                                                                              Colors.black,
                                                                          size:
                                                                              16,
                                                                        )
                                                                      : null,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                              _AnimatedDragHandle(
                                                                index: index,
                                                                size: 22,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            );

                                            if (isRestored) {
                                              content = content
                                                  .animate()
                                                  .scaleXY(
                                                    begin: 0.4,
                                                    end: 1.0,
                                                    duration: 400.ms,
                                                    curve: Curves.easeOutBack,
                                                  )
                                                  .fade(duration: 400.ms);
                                            }

                                            if (isHighlighted) {
                                              content = content
                                                  .animate(
                                                    delay: 800.ms,
                                                  ) // Wait for the scroll to finish
                                                  .shimmer(
                                                    duration: 1.seconds,
                                                    color: themeAccent
                                                        .withValues(alpha: 0.4),
                                                    angle: 1.2,
                                                  )
                                                  .tint(
                                                    color: themeAccent
                                                        .withValues(alpha: 0.25),
                                                    duration: 400.ms,
                                                  )
                                                  .then(delay: 0.ms)
                                                  .tint(
                                                    color: Colors.transparent,
                                                    duration: 600.ms,
                                                  );
                                            }

                                            return Builder(
                                              key: ValueKey(habit.id),
                                              builder: (itemContext) {
                                                // Auto-scroll to this specific habit if highlighted
                                                if (isHighlighted &&
                                                    _lastScrolledHighlight !=
                                                        habit.id) {
                                                  _lastScrolledHighlight =
                                                      habit.id;
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback((
                                                        _,
                                                      ) {
                                                        if (itemContext
                                                            .mounted) {
                                                          Scrollable.ensureVisible(
                                                            itemContext,
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      800,
                                                                ),
                                                            curve: Curves
                                                                .easeOutBack,
                                                            alignment:
                                                                0.5, // Places the item in the middle of the screen
                                                          );
                                                        }
                                                      });
                                                }

                                                return Container(
                                                  decoration: BoxDecoration(
                                                    border:
                                                        index <
                                                            widget
                                                                    .habits
                                                                    .length -
                                                                1
                                                        ? Border(
                                                            bottom: BorderSide(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.04,
                                                                  ),
                                                              width: 1,
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                  child: content,
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),

                                  // STYLED INTEGRATED ADD ACTION FOOTER TRACK
                                  InkWell(
                                    onTap: widget.onAddHabit,
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(24),
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: themeAccent.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              bottom: Radius.circular(24),
                                            ),
                                        border: Border(
                                          top: BorderSide(
                                            color: themeAccent.withValues(
                                              alpha: 0.15,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: themeAccent.withValues(
                                                alpha: 0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.add_rounded,
                                              color: themeAccent,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Add a habit",
                                            style: TextStyle(
                                              color: themeAccent,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                    // Left accent stripe: each routine's identity color as
                    // a thin edge instead of the old full-bleed wash.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: ColoredBox(color: widget.gradientColors.first),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDragHandle extends StatefulWidget {
  final int index;
  final double size;
  const _AnimatedDragHandle({required this.index, this.size = 24});

  @override
  State<_AnimatedDragHandle> createState() => _AnimatedDragHandleState();
}

class _AnimatedDragHandleState extends State<_AnimatedDragHandle> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: ReorderableDragStartListener(
        index: widget.index,
        child: AnimatedScale(
          scale: _isPressed ? 1.25 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: Icon(
            Icons.drag_indicator_rounded,
            color: Colors.white.withValues(alpha: 0.2),
            size: widget.size,
          ),
        ),
      ),
    );
  }
}
