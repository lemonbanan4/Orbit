// lib/screens/routine_detail_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/routine_provider.dart';
import '../../providers/ai_fairy_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../providers/atmosphere_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/reward_popup.dart';
import '../../widgets/telemetry_levelup_dialog.dart';
import '../../widgets/create_habit_sheet.dart';
import '../../widgets/manage_habit_dialog.dart';
import '../../widgets/common/premium_glass_card.dart';
import 'coaching_session_screen.dart';
import '../../theme/orbit_tokens.dart';
import '../../widgets/common/ai_fairy_overlay.dart';
import '../../widgets/preset_habit_selector.dart';
import '../../utils/time_picker_utils.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Same three routine-identity hues used on the dashboard card and its
// accent stripe, carried through as an ambient backdrop here instead of
// each session type inventing its own unrelated gradient (previously
// Morning was a loud solid orange while Work/Night were both near-black
// gradients differing only by a couple of tonal steps).
List<Color> _getBackgroundGradientColors(String sessionType) {
  switch (sessionType.toLowerCase()) {
    case 'morning':
      return [OrbitTokens.morning.withValues(alpha: 0.35), OrbitTokens.ground];
    case 'work':
    case 'workday':
      return [OrbitTokens.violet.withValues(alpha: 0.35), OrbitTokens.ground];
    case 'night':
    case 'nightly':
    default:
      return [OrbitTokens.teal.withValues(alpha: 0.35), OrbitTokens.ground];
  }
}

// Helper utility to get a prominent decorative header icon base
IconData _getHeaderIconData(String sessionType) {
  switch (sessionType.toLowerCase()) {
    case 'morning':
      return Icons.wb_sunny_rounded;
    case 'work':
    case 'workday':
      return Icons.fitness_center_rounded;
    default:
      return Icons.nightlight_round_rounded;
  }
}

class _IconMapping {
  static IconData fromCodePoint(int codePoint) {
    switch (codePoint) {
      case 0xe57c:
        return Icons.wb_sunny_rounded;
      case 0xe1af:
        return Icons.fitness_center_rounded;
      case 0xe7e9:
        return Icons.water_drop_rounded;
      // Add your preset codepoints here
      default:
        return Icons.star_rounded; // Safe fallback
    }
  }
}

class RoutineDetailScreen extends StatefulWidget {
  final String routineTitle;
  final String sessionType;
  final List<Color> gradientColors;
  final String time;

  const RoutineDetailScreen({
    super.key,
    required this.routineTitle,
    required this.sessionType,
    required this.gradientColors,
    required this.time,
  });

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _deletingIds = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgGradientColors = _getBackgroundGradientColors(widget.sessionType);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // LAYER 1: Dynamic Full-Screen Glassy Gradient Core
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: bgGradientColors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // LAYER 3: Sub-surface Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
          // LAYER 4: The Live Scrolling Context Interface
          Consumer<RoutineProvider>(
            builder: (context, routineProvider, child) {
              final routineHabits = routineProvider.getHabitsForRoutine(
                widget.sessionType,
              );
              final activeHabitsCount = routineHabits.length;

              return CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  decelerationRate: ScrollDecelerationRate.normal,
                ),
                slivers: [
                  // ==========================================
                  // UNIFIED SEAMLESS HEADER
                  // ==========================================
                  SliverAppBar(
                    expandedHeight: 200.0,
                    pinned: true,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                    backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      titlePadding: const EdgeInsets.only(
                        bottom: 16,
                        left: 16,
                        right: 16,
                      ),
                      title: Text(
                        widget.routineTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      background: Stack(
                        children: [
                          Positioned(
                            right: 0,
                            left: 0,
                            bottom: 0,
                            top: 0,
                            child: Icon(
                              _getHeaderIconData(widget.sessionType),
                              color: OrbitTokens.teal.withValues(alpha: 0.12),
                              size: 120,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 80,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.2),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 1,
                            left: 3,
                            child: GestureDetector(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                TimeOfDay initialTime;
                                try {
                                  final parts = widget.time.split(':');
                                  initialTime = TimeOfDay(
                                    hour: int.parse(parts[0]),
                                    minute: int.parse(parts[1]),
                                  );
                                } catch (_) {
                                  initialTime = TimeOfDay.now();
                                }
                                final TimeOfDay? newTime =
                                    await TimePickerUtils.showPremiumTimePicker(
                                      context: context,
                                      initialTime: initialTime,
                                    );
                                if (newTime != null) {
                                  routineProvider.updateRoutineTime(
                                    widget.sessionType,
                                    0,
                                    '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}',
                                  );
                                }
                              },
                              child:
                                  Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          routineProvider
                                                  .getRoutineTimes(
                                                    widget.sessionType,
                                                  )
                                                  .isNotEmpty
                                              ? routineProvider
                                                    .getRoutineTimes(
                                                      widget.sessionType,
                                                    )
                                                    .first
                                              : widget.time,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Courier',
                                          ),
                                        ),
                                      )
                                      .animate(
                                        onPlay: (c) => c.repeat(reverse: true),
                                      )
                                      .scaleXY(
                                        begin: 1.0,
                                        end: 1.05,
                                        duration: 2.seconds,
                                        curve: Curves.easeInOut,
                                      )
                                      .shimmer(
                                        delay: 1.seconds,
                                        duration: 2.seconds,
                                        color: Colors.white24,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ==========================================
                  // CARD INTERFACE CONTAINER
                  // ==========================================
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: PremiumGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: OrbitTokens.teal,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$activeHabitsCount habits',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Today',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    color: OrbitTokens.teal,
                                    size: 30,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      isScrollControlled: true,
                                      builder: (context) => PresetHabitSelector(
                                        onHabitSelected: (title, icon, color) {
                                          CreateHabitSheet.show(
                                            context,
                                            initialTitle: title,
                                            initialIcon: icon.codePoint,
                                            initialRoutine: widget.sessionType,
                                          );
                                        },
                                      ),
                                    );

                                    // CreateHabitSheet.show(
                                    //   context,
                                    //   initialRoutine: widget.sessionType,
                                    // );
                                  },
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: OrbitTokens.teal,
                                    size: 30,
                                  ),
                                  color: OrbitTokens.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  onSelected: (value) {
                                    HapticFeedback.lightImpact();
                                    if (value == 'reorder') {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Long-press items below to drag and reorder!',
                                          ),
                                        ),
                                      );
                                    } else if (value == 'time') {
                                      TimeOfDay initialTime;
                                      try {
                                        final parts = widget.time.split(':');
                                        initialTime = TimeOfDay(
                                          hour: int.parse(parts[0]),
                                          minute: int.parse(parts[1]),
                                        );
                                      } catch (_) {
                                        initialTime = TimeOfDay.now();
                                      }
                                      TimePickerUtils.showPremiumTimePicker(
                                        context: context,
                                        initialTime: initialTime,
                                      ).then((newTime) {
                                        if (newTime != null &&
                                            context.mounted) {
                                          context
                                              .read<RoutineProvider>()
                                              .updateRoutineTime(
                                                widget.sessionType,
                                                0,
                                                '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}',
                                              );
                                        }
                                      });
                                    } else if (value == 'alarms') {
                                      RoutineAlarmsSheet.show(
                                        context,
                                        widget.sessionType,
                                      );
                                    } else if (value == 'skip') {
                                      context
                                          .read<RoutineProvider>()
                                          .skipRoutine(widget.sessionType);
                                      Navigator.pop(context);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    const PopupMenuItem<String>(
                                      value: 'reorder',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.reorder_rounded,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Reorder items',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'time',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.alarm_rounded,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Change time',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'alarms',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.notifications_active_rounded,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Manage alarms',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'skip',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.skip_next_rounded,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Skip routine',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // CORE FLOW PLAY ACTION CONTAINER
                            Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: OrbitTokens.violet.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: OrbitTokens.violet,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.heavyImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CoachingSessionScreen(
                                            sessionType: widget.sessionType,
                                          ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Play',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // DYNAMIC CLEAN DECOUPLED HABIT LIST GENERATOR
                            Expanded(
                              child: ReorderableListView(
                                physics: const BouncingScrollPhysics(),
                                buildDefaultDragHandles: false,
                                onReorderItem: (oldIndex, newIndex) {
                                  context.read<RoutineProvider>().reorderHabits(
                                    widget.sessionType,
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
                                    debugPrint('Error playing click sound: $e');
                                  }
                                  Future.delayed(
                                    const Duration(milliseconds: 100),
                                    () => HapticFeedback.lightImpact(),
                                  );
                                },
                                onReorderEnd: (index) {
                                  HapticFeedback.heavyImpact();
                                },
                                proxyDecorator: (child, index, animation) {
                                  return Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: OrbitTokens.surface.withValues(
                                          alpha: 0.9,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: OrbitTokens.teal.withValues(
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
                                children: routineHabits.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final habit = entry.value;
                                  final isCompleted = habit.isCompleted;
                                  const highlightColor = OrbitTokens.teal;
                                  final isGoal = habit.isGoal;
                                  final isDeleting = _deletingIds.contains(
                                    habit.id,
                                  );
                                  final isRestored = context
                                      .read<RoutineProvider>()
                                      .recentlyRestoredHabitIds
                                      .contains(habit.id);

                                  Widget content = AnimatedOpacity(
                                    duration: const Duration(milliseconds: 300),
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
                                                motion: const DrawerMotion(),
                                                extentRatio: 0.45,
                                                children: [
                                                  SlidableAction(
                                                    onPressed: (actionContext) {
                                                      HapticFeedback.lightImpact();
                                                      CreateHabitSheet.show(
                                                        context,
                                                        habitId: habit.id,
                                                        initialTitle:
                                                            habit.title,
                                                        initialRoutine:
                                                            widget.sessionType,
                                                        initialIcon:
                                                            habit.iconCodePoint,
                                                        initialIsGoal:
                                                            habit.isGoal,
                                                        initialCategory:
                                                            habit.category,
                                                        initialActiveDays:
                                                            habit.activeDays,
                                                        initialTargetCount:
                                                            habit.targetCount,
                                                        initialUnit: habit.unit,
                                                      );
                                                    },
                                                    backgroundColor:
                                                        OrbitTokens.surface,
                                                    foregroundColor:
                                                        OrbitTokens.teal,
                                                    icon: Icons.edit_outlined,
                                                    label: 'Edit',
                                                  ),
                                                  SlidableAction(
                                                    onPressed: (actionContext) async {
                                                      HapticFeedback.heavyImpact();
                                                      final bool? confirm =
                                                          await ManageHabitDialog.show(
                                                            context,
                                                            habitId: habit.id,
                                                            habitTitle:
                                                                habit.title,
                                                            sessionType: widget
                                                                .sessionType,
                                                            iconCodePoint: habit
                                                                .iconCodePoint,
                                                            onDelete: () {},
                                                          );
                                                      if (confirm == true &&
                                                          context.mounted) {
                                                        final deletedHabit =
                                                            habit;

                                                        setState(() {
                                                          _deletingIds.add(
                                                            habit.id,
                                                          );
                                                        });

                                                        await Future.delayed(
                                                          const Duration(
                                                            milliseconds: 300,
                                                          ),
                                                        );
                                                        if (!context.mounted) {
                                                          return;
                                                        }

                                                        context
                                                            .read<
                                                              RoutineProvider
                                                            >()
                                                            .removeHabit(
                                                              habit.id,
                                                            );

                                                        setState(() {
                                                          _deletingIds.remove(
                                                            habit.id,
                                                          );
                                                        });

                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).clearSnackBars();
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    '${deletedHabit.title} deleted',
                                                                  ),
                                                                ),
                                                                GestureDetector(
                                                                  onTap: () =>
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).hideCurrentSnackBar(),
                                                                  child: const Icon(
                                                                    Icons.close,
                                                                    color: Colors
                                                                        .white54,
                                                                    size: 20,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            action: SnackBarAction(
                                                              label: 'UNDO',
                                                              textColor:
                                                                  OrbitTokens
                                                                      .teal,
                                                              onPressed: () {
                                                                context
                                                                    .read<
                                                                      RoutineProvider
                                                                    >()
                                                                    .restoreHabit(
                                                                      deletedHabit,
                                                                    );
                                                              },
                                                            ),
                                                            behavior:
                                                                SnackBarBehavior
                                                                    .floating,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            backgroundColor:
                                                                OrbitTokens
                                                                    .surface,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    backgroundColor: Colors
                                                        .redAccent
                                                        .withValues(alpha: 0.8),
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
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8.0,
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    splashColor: Colors.white
                                                        .withValues(alpha: 0.1),
                                                    highlightColor: Colors.white
                                                        .withValues(
                                                          alpha: 0.05,
                                                        ),
                                                    onLongPress:
                                                        habit.targetCount ==
                                                            null
                                                        ? null
                                                        : () {
                                                            HapticFeedback.mediumImpact();
                                                            context
                                                                .read<
                                                                  RoutineProvider
                                                                >()
                                                                .incrementHabitCount(
                                                                  habit.id,
                                                                  delta: -habit
                                                                      .currentCount,
                                                                );
                                                          },
                                                    onTap: () async {
                                                      final bool wasCompleted =
                                                          habit.isCompleted;
                                                      final int skips =
                                                          habit.skippedCount;

                                                      // 1. Capture the provider targets BEFORE toggling local mutations
                                                      final telemetry = context
                                                          .read<
                                                            TelemetryProvider
                                                          >();
                                                      final aiFairy = context
                                                          .read<
                                                            AIFairyProvider
                                                          >();
                                                      final atmosphereProvider =
                                                          context
                                                              .read<
                                                                AtmosphereProvider
                                                              >();
                                                      final soundsEnabled =
                                                          routineProvider
                                                              .soundsEnabled;

                                                      // 2. Trigger the state change mutation
                                                      if (habit.targetCount !=
                                                          null) {
                                                        await routineProvider
                                                            .incrementHabitCount(
                                                              habit.id,
                                                            );
                                                      } else {
                                                        await routineProvider
                                                            .toggleHabit(
                                                              habit.id,
                                                            );
                                                      }

                                                      // toggleHabit() can
                                                      // advance the streak
                                                      // internally (when it
                                                      // completes the last
                                                      // habit in a routine),
                                                      // so read the streak
                                                      // AFTER toggling --
                                                      // reading it before
                                                      // meant the exact
                                                      // completion that
                                                      // crossed a milestone
                                                      // was checked against
                                                      // the stale value and
                                                      // silently missed.
                                                      final streak =
                                                          routineProvider
                                                              .currentStreak;

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
                                                                (h) => h
                                                                    .isCompleted,
                                                              );
                                                      if (allCompleted) {
                                                        await NotificationService.clearActiveRoutineReminders();
                                                      }

                                                      if (!context.mounted) {
                                                        return;
                                                      }

                                                      // For count-based
                                                      // habits, a single tap
                                                      // may not reach the
                                                      // target yet -- only
                                                      // celebrate once
                                                      // isCompleted actually
                                                      // flips to true, not
                                                      // on every tap.
                                                      if (!wasCompleted &&
                                                          habit.isCompleted) {
                                                        HapticFeedback.lightImpact();

                                                        // Fire the cheer overlay directly into this view tree context
                                                        aiFairy.cheerForHabit(
                                                          habit.title,
                                                          streak,
                                                          playSound:
                                                              soundsEnabled,
                                                          skippedCount: skips,
                                                        );

                                                        atmosphereProvider.setAura(
                                                          AtmosphereProvider.auraForHabitCompletion(
                                                            streak: streak,
                                                            skippedCount: skips,
                                                          ),
                                                        );

                                                        // Award experience matrix points
                                                        bool didLevelUp =
                                                            await telemetry
                                                                .awardXp(15);

                                                        if (!context.mounted) {
                                                          return;
                                                        }

                                                        // Check for Milestone Unlocks
                                                        final newMilestones =
                                                            telemetry
                                                                .checkMilestoneUnlocks(
                                                                  streak,
                                                                );
                                                        if (newMilestones
                                                            .isNotEmpty) {
                                                          final thresholds = [
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
                                                                    Icons
                                                                        .emoji_events_rounded,
                                                                    color:
                                                                        OrbitTokens
                                                                            .gold,
                                                                    size: 28,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  Expanded(
                                                                    child: Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        const Text(
                                                                          "MILESTONE UNLOCKED",
                                                                          style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w900,
                                                                            fontSize:
                                                                                12,
                                                                            letterSpacing:
                                                                                1.2,
                                                                            color:
                                                                                OrbitTokens.gold,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          "$days Day Streak Achieved!",
                                                                          style: const TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                            fontSize:
                                                                                14,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              backgroundColor:
                                                                  OrbitTokens
                                                                      .surface,
                                                              behavior:
                                                                  SnackBarBehavior
                                                                      .floating,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                                side: BorderSide(
                                                                  color: OrbitTokens
                                                                      .gold
                                                                      .withValues(
                                                                        alpha:
                                                                            0.5,
                                                                      ),
                                                                  width: 1.5,
                                                                ),
                                                              ),
                                                              margin:
                                                                  const EdgeInsets.only(
                                                                    bottom: 24,
                                                                    left: 24,
                                                                    right: 24,
                                                                  ),
                                                              duration:
                                                                  const Duration(
                                                                    seconds: 4,
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
                                                        } else {
                                                          // Render the popup configuration overlay context panel
                                                          RewardPopup.show(
                                                            context,
                                                            title:
                                                                "Habit Completed!",
                                                            xpEarned: 15,
                                                            currentTotalXp:
                                                                telemetry
                                                                    .globalXp,
                                                          );
                                                        }
                                                      } else if (habit
                                                              .targetCount !=
                                                          null) {
                                                        // A count-based tap
                                                        // that didn't reach
                                                        // target yet -- still
                                                        // give a light tap
                                                        // confirmation.
                                                        HapticFeedback.selectionClick();
                                                      }
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8.0,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            _IconMapping.fromCodePoint(
                                                              habit
                                                                  .iconCodePoint,
                                                            ),
                                                            color: isCompleted
                                                                ? Colors.white30
                                                                : highlightColor,
                                                            size: 28,
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Text(
                                                                  habit.title,
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    color:
                                                                        isCompleted
                                                                        ? Colors
                                                                              .white54
                                                                        : Colors
                                                                              .white,
                                                                    decoration:
                                                                        isCompleted
                                                                        ? TextDecoration
                                                                              .lineThrough
                                                                        : null,
                                                                  ),
                                                                  maxLines:
                                                                      null,
                                                                  softWrap:
                                                                      true,
                                                                ),
                                                                if (!habit
                                                                    .isActiveOn())
                                                                  const Text(
                                                                    'Not scheduled today',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .white38,
                                                                      fontSize:
                                                                          11,
                                                                      fontStyle:
                                                                          FontStyle
                                                                              .italic,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                          if (isGoal)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical: 4,
                                                                  ),
                                                              margin:
                                                                  const EdgeInsets.only(
                                                                    right: 12,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                'Goal',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.7,
                                                                      ),
                                                                ),
                                                              ),
                                                            ),
                                                          AnimatedContainer(
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      200,
                                                                ),
                                                            width:
                                                                habit.targetCount ==
                                                                        null ||
                                                                    isCompleted
                                                                ? 28
                                                                : 40,
                                                            height: 28,
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: isCompleted
                                                                  ? highlightColor
                                                                  : Colors
                                                                        .transparent,
                                                              border: Border.all(
                                                                color:
                                                                    isCompleted
                                                                    ? highlightColor
                                                                    : Colors
                                                                          .white
                                                                          .withValues(
                                                                            alpha:
                                                                                0.5,
                                                                          ),
                                                                width: 2,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                            alignment: Alignment
                                                                .center,
                                                            child: isCompleted
                                                                ? const Icon(
                                                                    Icons
                                                                        .check_rounded,
                                                                    color: Colors
                                                                        .black,
                                                                    size: 18,
                                                                  )
                                                                : habit.targetCount !=
                                                                      null
                                                                ? Text(
                                                                    '${habit.currentCount}/${habit.targetCount}',
                                                                    style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  )
                                                                : null,
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          _AnimatedDragHandle(
                                                            index: index,
                                                            size: 24,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
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

                                  return Container(
                                    key: ValueKey(habit.id),
                                    child: content,
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const Align(
            alignment: Alignment.center,
            child: AIFairyOverlay(bottomPadding: 0),
          ),
        ],
      ),
    );
  }
}

class RoutineAlarmsSheet extends StatelessWidget {
  final String routineType;
  const RoutineAlarmsSheet({super.key, required this.routineType});

  static void show(BuildContext context, String routineType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoutineAlarmsSheet(routineType: routineType),
    );
  }

  Future<bool> requestNotificationPermissions() async {
    final status = await Permission.notification.request();

    if (status.isGranted) {
      debugPrint("Notification permission granted.");
      return true;
    } else if (status.isPermanentlyDenied) {
      debugPrint("Notification permission permanently denied.");

      await openAppSettings();
      return false;
    } else {
      debugPrint("Notification permission denied.");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: OrbitTokens.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$routineType Alarms',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_alert_rounded,
                    color: OrbitTokens.teal,
                  ),
                  onPressed: () async {
                    final TimeOfDay? newTime =
                        await TimePickerUtils.showPremiumTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                    if (newTime != null && context.mounted) {
                      final added = context.read<RoutineProvider>().addRoutineAlarm(
                        routineType,
                        '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}',
                      );
                      if (!added && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Max ${RoutineProvider.maxAlarmsPerRoutine} alarms per routine.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<RoutineProvider>(
                builder: (context, provider, child) {
                  final alarms = provider.getRoutineAlarms(routineType);
                  if (alarms.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_rounded,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No alarms set.\nAdd one to get notified!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: alarms.length,
                    itemBuilder: (context, index) {
                      final alarm = alarms[index];
                      final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: PremiumGlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      // A malformed/empty alarm.time (partial
                                      // write, migration artifact) used to
                                      // throw here uncaught -- the two
                                      // sibling time pickers in this file
                                      // already guard the same parse.
                                      TimeOfDay initialTime;
                                      try {
                                        final parts = alarm.time.split(':');
                                        initialTime = TimeOfDay(
                                          hour: int.parse(parts[0]),
                                          minute: int.parse(parts[1]),
                                        );
                                      } catch (_) {
                                        initialTime = TimeOfDay.now();
                                      }
                                      final newTime =
                                          await TimePickerUtils.showPremiumTimePicker(
                                            context: context,
                                            initialTime: initialTime,
                                          );
                                      if (newTime != null && context.mounted) {
                                        provider.updateRoutineTime(
                                          routineType,
                                          index,
                                          '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}',
                                        );
                                      }
                                    },
                                    child: Text(
                                      alarm.time,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Courier',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () {
                                      provider.removeRoutineAlarm(
                                        routineType,
                                        index,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(7, (dayIndex) {
                                  final isActive = alarm.activeDays[dayIndex];
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      provider.toggleAlarmDay(
                                        routineType,
                                        index,
                                        dayIndex,
                                      );
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? OrbitTokens.teal
                                            : Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isActive
                                              ? OrbitTokens.teal
                                              : Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        days[dayIndex],
                                        style: TextStyle(
                                          color: isActive
                                              ? Colors.black
                                              : Colors.white54,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ).animate().fade().slideY(begin: 0.1),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
