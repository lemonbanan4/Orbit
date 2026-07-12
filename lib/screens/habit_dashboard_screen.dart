// lib/screens/habit_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';

import '../providers/routine_provider.dart';
import '../providers/auth_provider.dart';

import '../services/ai_coach_service.dart';
import '../widgets/create_habit_sheet.dart';
import '../screens/paywall/paywall_screen.dart';
import '../widgets/common/base_orbit_screen.dart';
import '../theme/orbit_colors.dart';
import '../widgets/common/premium_glass_card.dart';
import '../widgets/common/ai_fairy_overlay.dart';
import 'social/invite_partner_screen.dart';
import '../widgets/preset_habit_selector.dart';
import '../widgets/routine_card.dart';
import 'sanctuary/sanctuary_screen.dart';
import 'features/celestial_reflection_screen.dart';
import 'features/nebula_forge_screen.dart';
import 'features/pro_coaching_screen.dart';
import '../widgets/sleep_audio_bottom_sheet.dart';
import 'coaching/coaching_session_screen.dart';
import 'package:orbit_app/theme/custom_colors.dart';
import '../widgets/paywall/premium_paywall_dialog.dart';
import '../utils/time_picker_utils.dart';

class HabitDashboardScreen extends StatefulWidget {
  final bool isFirstLaunch;
  final String? highlightHabit;

  const HabitDashboardScreen({
    super.key,
    this.isFirstLaunch = false,
    this.highlightHabit,
  });

  @override
  State<HabitDashboardScreen> createState() => _HabitDashboardScreenState();
}

class _HabitDashboardScreenState extends State<HabitDashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  String _currentAiInsight = "Analyzing your orbit...";
  String _lastInsightState = "";
  String? _latestSkipReason;
  late ConfettiController _confettiController;
  bool _hasCelebratedToday = false;
  late AnimationController _panController;
  bool _isGeneratingIntention = false;
  bool _hasConsultedMirrorToday = false;
  bool _pendingInsightCallback = false;

  final List<Map<String, dynamic>> _routineConfigs = [
    {
      'type': 'Morning',
      'title': 'Morning Routine',
      'session': 'daily',
      'colors': [
        const Color(0xFFFF5E00),
        const Color(0xFFFF5E00).withValues(alpha: 0.7),
      ],
    },
    {
      'type': 'Work',
      'title': 'Work Routine',
      'session': 'workday',
      'colors': [
        const Color(0xFF2B0057),
        const Color(0xFF2B0057).withValues(alpha: 0.7),
      ],
    },
    {
      'type': 'Night',
      'title': 'Night Routine',
      'session': 'nightly',
      'colors': [
        const Color(0xFF051024),
        const Color(0xFF051024).withValues(alpha: 0.7),
      ],
    },
  ];

  final List<String> _quotes = [
    "We are what we repeatedly do.",
    "Small disciplines lead to massive achievements.",
    "The secret of your future is hidden in your daily routine.",
    "Win the morning, win the day.",
  ];
  String _dailyQuote = "";

  bool get _isPro => context.read<AppAuthProvider>().isPro ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleInsightUpdate();
  }

  void _scheduleInsightUpdate() {
    final routineProvider = context.read<RoutineProvider>();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        !routineProvider.isDataLoaded ||
        _pendingInsightCallback) {
      return;
    }
    _pendingInsightCallback = true;
    final docs = routineProvider.habits.values.toList();
    final completedCount = docs.where((h) => h.isCompleted).length;
    final progress = docs.isEmpty ? 0.0 : completedCount / docs.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingInsightCallback = false;
      if (!mounted) return;
      _updateInsight(completedCount, docs.length);
      if (progress >= 1.0 && !_hasCelebratedToday && docs.isNotEmpty) {
        setState(() => _hasCelebratedToday = true);
        _confettiController.play();
        HapticFeedback.heavyImpact();
      } else if (progress < 1.0 && _hasCelebratedToday) {
        setState(() => _hasCelebratedToday = false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDailyStatus();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _panController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat(reverse: true);
    _quotes.shuffle();
    _dailyQuote = _quotes.first;

    _loadRoutineOrder();
  }

  Future<void> _loadRoutineOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getStringList('routine_order');
    if (order != null && order.length == _routineConfigs.length && mounted) {
      setState(() {
        _routineConfigs.sort(
          (a, b) => order
              .indexOf(a['type'] as String)
              .compareTo(order.indexOf(b['type'] as String)),
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _confettiController.dispose();
    _panController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDailyStatus();
    }
  }

  Future<void> _checkDailyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastConsultDate = prefs.getString('last_mirror_consult_date');
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (mounted) {
      setState(() => _hasConsultedMirrorToday = lastConsultDate == today);
    }
  }

  void _updateInsight(int completed, int total) async {
    if (!_isPro) {
      setState(
        () => _currentAiInsight =
            "Upgrade to Orbit Pro for personalized insights!",
      );
      return;
    }
    final stateKey = "${completed}_$total";
    if (_lastInsightState == stateKey) return;
    _lastInsightState = stateKey;

    int currentStreak = 0;
    List<String> skipReasons = [];
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 3));

        currentStreak = userDoc.data()?['current_streak'] as int? ?? 0;

        final skippedDocs = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('skipped_sessions')
            .orderBy('timestamp', descending: true)
            .limit(3)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 3));

        skipReasons = skippedDocs.docs
            .map((d) => (d.data())['reason'] as String)
            .toList();
        if (mounted && skipReasons.isNotEmpty) {
          _latestSkipReason = skipReasons.first;
        }
      } catch (e) {
        debugPrint("Offline or timeout fetching telemetry: $e");
      }
    }

    try {
      final insight = await AiCoachService.generateInsight(
        completedCount: completed,
        totalHabits: total,
        currentStreak: currentStreak,
        recentSkipReasons: skipReasons.isNotEmpty ? skipReasons : null,
      );

      if (mounted) setState(() => _currentAiInsight = insight);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _currentAiInsight = "The cosmos is quiet. Keep pushing forward.",
        );
      }
    }
  }

  Future<void> _openTimeBasedCoachingSession(BuildContext context) async {
    final hour = DateTime.now().hour;
    String sessionType;

    if (hour >= 5 && hour < 11) {
      sessionType = 'daily';
    } else if (hour >= 11 && hour < 17) {
      sessionType = 'workday';
    } else {
      sessionType = 'nightly';
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CoachingSessionScreen(sessionType: sessionType),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString('last_mirror_consult_date', today);

    if (mounted) {
      setState(() => _hasConsultedMirrorToday = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbitColors = theme.extension<OrbitColors>();
    final Color orbColor1 = orbitColors?.orbColor1 ?? const Color(0xFF00E5FF);
    final Color textColor = theme.colorScheme.onSurface;
    final bool isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return BaseOrbitScreen(
      title: 'Orbit',
      actions: [
        IconButton(
          icon: const Icon(Icons.group_add_rounded, color: Color(0xFF00E5FF)),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvitePartnerScreen()),
            );
          },
        ),
        const SizedBox(width: 16),
      ],

      // floatingActionButton: Padding(
      //   padding: const EdgeInsets.only(bottom: 16.0),
      //   child: Row(
      //     mainAxisSize: MainAxisSize.min,
      //     children: [
      //       const SizedBox(width: 12),
      //       // 1. Wrap in a SizedBox to perfectly control the width and height
      //       SizedBox(
      //         width: 100, // Set the exact horizontal width you want
      //         height: 54, // Match a standard comfortable FAB height
      //         child: AnimatedFrostyButton(
      //           text: 'New Habit',
      //           onPressed: () {
      //             HapticFeedback.lightImpact();
      //             showModalBottomSheet(
      //               context: context,
      //               backgroundColor: Colors.transparent,
      //               isScrollControlled: true,
      //               builder: (context) => PresetHabitSelector(
      //                 onHabitSelected: (title, icon, color) {
      //                   CreateHabitSheet.show(
      //                     context,
      //                     initialTitle: title,
      //                     initialIcon: icon.codePoint,
      //                   );
      //                 },
      //               ),
      //             );
      //           },
      //         ),
      //       ),
      //     ],
      //   ),
      // ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12),
            FloatingActionButton.extended(
              heroTag: 'new_habit',
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
                      );
                    },
                  ),
                );
              },
              backgroundColor: const Color(0xFF051024).withValues(
                alpha: 0.7,
              ), //const Color(0xFF00E5FF).withValues(alpha: 0.6),
              foregroundColor: Color(0xFF00E5FF), //Colors.black,
              icon: const Icon(Icons.add_rounded, size: 24),
              label: const Text(
                'New Habit',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 8,
            ),
          ],
        ),
      ),

      // body: Stack(
      //   children: [
      //     // 🚀 STEP 1: Add the premium onboarding gradient background container as the bottom layer
      //     Positioned.fill(
      //       child: Container(
      //         decoration: const BoxDecoration(
      //           gradient: LinearGradient(
      //             begin: Alignment.topCenter,
      //             end: Alignment.bottomCenter,
      //             colors: [
      //               //Color(0xFF00E5FF), // cosmicCyan hex mapping
      //               Color(0xFF051024), // deepNavy hex mapping
      //               Color(0xFF050112), // cosmicBlack hex mapping
      //             ],
      //           ),
      //         ),
      //       ),
      //     ),

      //     // 🪐 STEP 2: Your existing interactive Parallax Nebula asset shifts down on top of it
      //     // Positioned(
      //     //   top: -100,
      //     //   left: -100,
      //     //   right: -100,
      //     //   bottom: -100,
      //     //   child: AnimatedBuilder(
      //     //     animation: Listenable.merge([_scrollController, _panController]),
      //     //     child: Opacity(
      //     //       // The gradient will perfectly bleed right through this opacity wrapper!
      //     //       opacity: isDark ? 0.4 : 0.1,
      //     //       child: Image.asset(
      //     //         'assets/images/nebula_bg.png',
      //     //         fit: BoxFit.cover,
      //     //       ),
      //     //     ),
      //     //     builder: (context, child) {
      //     //       double parallaxOffset = _scrollController.hasClients
      //     //           ? _scrollController.offset * -0.1
      //     //           : 0.0;
      //     //       double panOffset = (_panController.value - 0.5) * 50;
      //     //       return Transform.translate(
      //     //         offset: Offset(panOffset, parallaxOffset),
      //     //         child: child,
      //     //       );
      //     //     },
      //     //   ),
      //     // ),

      // ... your dashboard grid elements, lists, and scroll views continue here ...
      body: Stack(
        children: [
          Positioned(
            top: -200,
            left: -100,
            right: -100,
            bottom: -200,
            child: AnimatedBuilder(
              animation: Listenable.merge([_scrollController, _panController]),
              child: Opacity(
                opacity: isDark ? 0.4 : 0.1,
                child: Image.asset(
                  'assets/images/nebula_bg.png',
                  fit: BoxFit.cover,
                ),
              ),
              builder: (context, child) {
                double offset = _scrollController.hasClients
                    ? _scrollController.offset
                    : 0.0;

                // 1. Raw parallax effect
                double parallaxOffset = offset * -0.1;

                // 2. Clamp translation to exactly match our extra bleed room (200px) so edges never show
                parallaxOffset = parallaxOffset.clamp(-200.0, 200.0);

                // 3. Horizontal slow pan
                double panOffset = (_panController.value - 0.5) * 50;

                // 4. Premium edge stretch effect on overscroll
                double scale = 1.0;
                if (_scrollController.hasClients &&
                    _scrollController.position.hasContentDimensions) {
                  double maxScroll = _scrollController.position.maxScrollExtent;
                  if (offset < 0) {
                    scale = 1.0 + (offset.abs() * 0.0015);
                  } else if (offset > maxScroll && maxScroll > 0) {
                    scale = 1.0 + ((offset - maxScroll) * 0.0015);
                  }
                }

                return Transform.translate(
                  offset: Offset(panOffset, parallaxOffset),
                  child: Transform.scale(scale: scale, child: child),
                );
              },
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    PremiumGlassCard(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: orbColor1,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Cosmica's Insights",
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.5),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.only(right: 60),
                                child: SizedBox(
                                  height: 75,
                                  child: TweenAnimationBuilder<int>(
                                    key: ValueKey(_currentAiInsight),
                                    tween: IntTween(
                                      begin: 0,
                                      end: _currentAiInsight.length,
                                    ),
                                    duration: Duration(
                                      milliseconds:
                                          (_currentAiInsight.length * 30).clamp(
                                            500,
                                            3000,
                                          ),
                                    ),
                                    builder: (context, value, child) {
                                      final showCursor =
                                          (value < _currentAiInsight.length) &&
                                          (DateTime.now().millisecondsSinceEpoch ~/
                                                      400) %
                                                  2 ==
                                              0;
                                      return Text(
                                        _currentAiInsight.substring(0, value) +
                                            (showCursor ? ' ▌' : ''),
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          height: 1.5,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Divider(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),

                              const SizedBox(height: 8),
                              Consumer<RoutineProvider>(
                                builder: (context, routineProvider, child) {
                                  return GestureDetector(
                                    onTap: () async {
                                      HapticFeedback.lightImpact();

                                      if (!_isPro) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const PaywallScreen(),
                                          ),
                                        );
                                        return;
                                      }

                                      if (routineProvider
                                              .dailyIntention
                                              ?.isEmpty ??
                                          true) {
                                        setState(
                                          () => _isGeneratingIntention = true,
                                        );
                                        final aiIntention =
                                            await AiCoachService.generateDailyIntention(
                                              latestSkipReason:
                                                  _latestSkipReason,
                                            );
                                        await routineProvider.setDailyIntention(
                                          aiIntention,
                                        );
                                        setState(
                                          () => _isGeneratingIntention = false,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          _isGeneratingIntention
                                              ? SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: orbColor1,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Icon(
                                                  (routineProvider
                                                              .dailyIntention
                                                              ?.isNotEmpty ??
                                                          false)
                                                      ? Icons.flare_rounded
                                                      : Icons
                                                            .add_circle_outline_rounded,
                                                  color: orbColor1,
                                                  size: 16,
                                                ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              (routineProvider
                                                          .dailyIntention
                                                          ?.isNotEmpty ??
                                                      false)
                                                  ? '"${routineProvider.dailyIntention}"'
                                                  : 'Tap to let Cosmica set your intention...',
                                              style: TextStyle(
                                                color: textColor.withValues(
                                                  alpha: 0.9,
                                                ),
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (!_hasConsultedMirrorToday) ...[
                                const SizedBox(height: 16),
                                _ConsultMirrorButton(
                                  orbColor: orbColor1,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _openTimeBasedCoachingSession(context);
                                  },
                                ),
                              ],
                            ],
                          ),
                          Positioned(
                            top: -10,
                            right: -15,
                            child:
                                SizedBox(
                                      width: 70,
                                      height: 70,
                                      child: Image.asset(
                                        'assets/images/fairy_avatar.png',
                                      ),
                                    )
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .moveY(
                                      begin: -6,
                                      end: 6,
                                      duration: 2.seconds,
                                      curve: Curves.easeInOut,
                                    ),
                            // .shimmer(
                            //   delay: 3.seconds,
                            //   color: Colors.white,
                            // ),
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 800.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 40),
                    Text(
                      "Today's Path",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (user != null)
                      Consumer<RoutineProvider>(
                        builder: (context, routineProvider, child) {
                          if (!routineProvider.isDataLoaded) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 40.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF00E5FF),
                                ),
                              ),
                            );
                          }
                          final docs = routineProvider.habits.values.toList();
                          docs.sort((a, b) => a.order.compareTo(b.order));

                          return Column(
                            children: _routineConfigs.asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final config = entry.value;
                              final routineType = config['type'] as String;
                              final routineHabits = routineProvider
                                  .getHabitsForRoutine(routineType);
                              final times = routineProvider.getRoutineTimes(
                                routineType,
                              );
                              final timeString = times.isNotEmpty
                                  ? times.first
                                  : '00:00';

                              //  REWRITTEN CLEAN LIST MAP RETURNING VECTOR CORNER RENDERS DIRECTLY
                              return KeyedSubtree(
                                key: ValueKey(routineType),
                                child:
                                    RoutineCard(
                                          title: config['title'] as String,
                                          time: timeString,
                                          sessionType: routineType,
                                          habits: routineHabits,
                                          highlightHabit: widget.highlightHabit,
                                          gradientColors:
                                              config['colors'] as List<Color>,
                                          onTimeTapped: () async {
                                            final TimeOfDay? newTime =
                                                await TimePickerUtils.showPremiumTimePicker(
                                                  context: context,
                                                  initialTime: TimeOfDay(
                                                    hour: int.parse(
                                                      timeString.split(':')[0],
                                                    ),
                                                    minute: int.parse(
                                                      timeString.split(':')[1],
                                                    ),
                                                  ),
                                                );
                                            if (newTime != null && mounted) {
                                              routineProvider.updateRoutineTime(
                                                routineType,
                                                0,
                                                '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}',
                                              );
                                            }
                                          },
                                          onReorder: (oldIndex, newIndex) {
                                            HapticFeedback.heavyImpact();
                                            routineProvider.reorderHabits(
                                              routineType,
                                              oldIndex,
                                              newIndex,
                                            );
                                          },
                                          onDeleteHabit: (habitId) {
                                            HapticFeedback.mediumImpact();
                                            final deletedHabit =
                                                routineProvider.habits[habitId];
                                            routineProvider.removeHabit(
                                              habitId,
                                            );

                                            if (deletedHabit != null) {
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
                                                          color: Colors.white54,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  action: SnackBarAction(
                                                    label: 'UNDO',
                                                    textColor: const Color(
                                                      0xFF00E5FF,
                                                    ),
                                                    onPressed: () {
                                                      routineProvider
                                                          .restoreHabit(
                                                            deletedHabit,
                                                          );
                                                    },
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  backgroundColor: const Color(
                                                    0xFF1F1235,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          onSkipRoutine: () {
                                            HapticFeedback.lightImpact();
                                            routineProvider.skipRoutine(
                                              routineType,
                                            );
                                          },
                                          onAddHabit: () {
                                            HapticFeedback.lightImpact();
                                            showModalBottomSheet(
                                              context: context,
                                              backgroundColor:
                                                  Colors.transparent,
                                              isScrollControlled: true,
                                              builder: (context) =>
                                                  PresetHabitSelector(
                                                    onHabitSelected:
                                                        (title, icon, color) {
                                                          CreateHabitSheet.show(
                                                            context,
                                                            initialTitle: title,
                                                            initialIcon:
                                                                icon.codePoint,
                                                            initialRoutine:
                                                                routineType,
                                                          );
                                                        },
                                                  ),
                                            );
                                          },
                                        )
                                        .animate()
                                        .fade(
                                          delay: (200 + (index * 150)).ms,
                                          duration: 600.ms,
                                        )
                                        .slideY(
                                          begin: 0.2,
                                          duration: 800.ms,
                                          curve: Curves.easeOutBack,
                                        )
                                        .scaleXY(
                                          begin: 0.95,
                                          end: 1.0,
                                          delay: (200 + (index * 150)).ms,
                                          duration: 800.ms,
                                          curve: Curves.easeOutBack,
                                        )
                                        .shimmer(
                                          delay: (800 + (index * 150)).ms,
                                          duration: 1.seconds,
                                          color: Colors.white24,
                                        ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    Consumer<AppAuthProvider>(
                      builder: (context, appAuth, child) {
                        return _PremiumCarousel(
                          isPro: appAuth.isPro ?? false,
                          onOpenSanctuary: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SanctuaryScreen(),
                              ),
                            );
                          },
                          onOpenReflection: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CelestialReflectionScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _DailyQuoteCard(quote: _dailyQuote),
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 40,
                gravity: 0.15,
                colors: const [
                  Colors.orange,
                  Colors.cyan,
                  Colors.purple,
                  Colors.white,
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: AIFairyOverlay(),
          ),
        ],
      ),
    );
  }
}

class _PremiumCarousel extends StatelessWidget {
  final bool isPro;
  final VoidCallback onOpenSanctuary;
  final VoidCallback onOpenReflection;

  const _PremiumCarousel({
    required this.isPro,
    required this.onOpenSanctuary,
    required this.onOpenReflection,
  });

  void _showPaywall(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (context) => PremiumPaywallDialog(
        title: title,
        description: description,
        onCancelPressed: () => Navigator.pop(context),
        onUpgradePressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaywallScreen()),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            "Your Daily Coachings",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCarouselCard(
                context: context,
                index: 0,
                title: "The Sanctuary",
                subtitle: "Unroll today's wisdom.",
                duration: "1 min",
                gradient: const [
                  deepPurple, black87, //Color(0xFF4A00E0)
                ],
                icon: Icons.auto_stories_rounded,
                onTap: onOpenSanctuary,
              ),
              _buildCarouselCard(
                context: context,
                index: 1,
                title: "Celestial Reflection",
                subtitle: "Find your center and relax.",
                duration: "3 min",
                gradient: const [deepOrange, black87],
                icon: Icons.bubble_chart_rounded,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (isPro) {
                    onOpenReflection();
                  } else {
                    _showPaywall(
                      context,
                      "Unlock Celestial Reflection",
                      "Upgrade to Pro to find your center and relax with advanced meditation features and guided breathwork.",
                    );
                  }
                },
              ),
              _buildCarouselCard(
                context: context,
                index: 2,
                title: "The Nebula Forge",
                subtitle: "Analyze your gravitational synergy.",
                duration: "Telemetry",
                gradient: const [
                  deepBlue,
                  black87,
                  //Color.fromARGB(255, 7, 0, 0),
                ],
                icon: Icons.hub_rounded,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (isPro) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NebulaForgeScreen(
                          sourcePhase: "Live Grid Dashboard",
                        ),
                      ),
                    );
                  } else {
                    _showPaywall(
                      context,
                      "Unlock The Nebula Forge",
                      "Upgrade to Pro to deeply analyze your habit correlations, gravitational synergy, and long-term orbital trajectories.",
                    );
                  }
                },
              ),
              _buildCarouselCard(
                context: context,
                index: 3,
                title: "Deep Sleep Audio",
                subtitle: "Binaural beats for recovery.",
                duration: "45 min",
                gradient: const [
                  cosmicWhite, black87,
                  //Color(0xFF0B191E)
                ],
                icon: Icons.nightlight_round_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (isPro) {
                    SleepAudioBottomSheet.show(context);
                  } else {
                    _showPaywall(
                      context,
                      "Unlock Deep Sleep Audio",
                      "Upgrade to Pro to access premium binaural beats, deep space soundscapes, and advanced recovery audio sessions.",
                    );
                  }
                },
              ),
              _buildCarouselCard(
                context: context,
                index: 4,
                title: "Pro-Only Coaching",
                subtitle: "Unlock advanced AI insights.",
                duration: "Exclusive",
                gradient: const [
                  cosmicCyan,
                  black87,
                  //Color(0xFF1A1F36), //.withValues(alpha: 0.1),
                  //Color(0xFF1A1F36), //.withValues(alpha: 0.1),
                ],
                //Color(0xFFFF416C), Color(0xFFFF4B2B)],
                icon: Icons.workspace_premium_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (isPro) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProCoachingScreen(),
                      ),
                    );
                  } else {
                    _showPaywall(
                      context,
                      "Unlock Pro Coaching",
                      "Upgrade to Pro to access personalized AI coaching sessions, deeper insights, and advanced habit analysis. Elevate your journey with the full power of the Nebula Forge!",
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // showDialog(
  //   context: context,
  //   builder: (context) => AlertDialog(
  //     title: const Text(
  //       "Unlock Pro Coaching",
  //       style: TextStyle(color: Colors.white),
  //     ),
  //     content: const Text(
  //       "Upgrade to Pro to access personalized AI coaching sessions, deeper insights, and advanced habit analysis. Elevate your journey with the full power of the Nebula Forge!",
  //     ),
  //     gradient: const LinearGradient(
  //       begin: Alignment.topLeft,
  //       end: Alignment.bottomRight,
  //       colors: [
  //         cosmicCyan,
  //         black87,
  //       ],
  //     ),
  //     actions: [
  //       TextButton(
  //         onPressed: () => Navigator.pop(context),
  //         child: const Text("Not Now"),
  //       ),
  //       ElevatedButton(
  //         onPressed: () {
  //           Navigator.pop(context);
  //           Navigator.push(
  //             context,
  //             MaterialPageRoute(
  //               builder: (_) => const PaywallScreen(),
  //             ),
  //           );
  //         },
  //         child: const Text("Upgrade to Pro"),
  //       ),
  //     ],
  //   ),
  // );

  Widget _buildCarouselCard({
    required BuildContext context,
    required int index,
    required String title,
    required String subtitle,
    required String duration,
    required List<Color> gradient,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 160,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      duration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(icon, color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fade(delay: (400 + (index * 100)).ms, duration: 600.ms)
        .slideX(begin: 0.2, duration: 600.ms, curve: Curves.easeOutQuart)
        .scaleXY(
          begin: 0.9,
          end: 1.0,
          delay: (400 + (index * 100)).ms,
          duration: 600.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _DailyQuoteCard extends StatelessWidget {
  final String quote;
  const _DailyQuoteCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbColor1 =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);
    return PremiumGlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, color: orbColor1, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DAILY WISDOM",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '"$quote"',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 500.ms).slideY(begin: 0.1);
  }
}

class _ConsultMirrorButton extends StatefulWidget {
  final Color orbColor;
  final VoidCallback onPressed;

  const _ConsultMirrorButton({required this.orbColor, required this.onPressed});

  @override
  State<_ConsultMirrorButton> createState() => _ConsultMirrorButtonState();
}

class _ConsultMirrorButtonState extends State<_ConsultMirrorButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _glowAnimation = Tween<double>(
      begin: 0.15,
      end: 0.35,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onPressed,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text(
                'Consult the Mirror',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.orbColor.withValues(
                  alpha: _glowAnimation.value,
                ),
                foregroundColor: widget.orbColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  side: BorderSide(
                    color: widget.orbColor.withValues(
                      alpha: _glowAnimation.value + 0.15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
