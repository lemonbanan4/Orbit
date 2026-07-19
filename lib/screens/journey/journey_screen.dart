import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:orbit_app/providers/atmosphere_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/routine_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../widgets/journey/upgraded_milestone_card.dart';
import '../../widgets/journey/shareable_streak_card.dart';
import '../../widgets/common/stellar_planet.dart';
import '../../services/share_service.dart';
import '../../theme/orbit_tokens.dart';

// // Ensure correct path for reflection route

// --- DYNAMIC MILESTONE METADATA DATA MODEL ---
class JourneyMilestone {
  final String phase;
  final String title;
  final String subtitle;
  final int requiredStreak;
  final IconData rewardIcon;
  final String rewardName;

  const JourneyMilestone({
    required this.phase,
    required this.title,
    required this.subtitle,
    required this.requiredStreak,
    required this.rewardIcon,
    required this.rewardName,
  });
}

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final ScrollController _scrollController = ScrollController();

  // Real SaaS Milestone Path Data
  final List<JourneyMilestone> _milestones = const [
    JourneyMilestone(
      phase: "PHASE 1",
      title: "Cosmic Ignition",
      subtitle:
          "Break free from gravitational inertia. Form your first atomic routine.",
      requiredStreak: 1,
      rewardIcon: Icons.flare_rounded,
      rewardName: "Stardust Particle Badge",
    ),
    JourneyMilestone(
      phase: "PHASE 2",
      title: "Stardust Voyager",
      subtitle:
          "Maintain velocity through the stream. Establish habit structural consistency.",
      requiredStreak: 3,
      rewardIcon: Icons.explore_rounded,
      rewardName: "Atmosphere Aura Editor",
    ),
    JourneyMilestone(
      phase: "PHASE 3",
      title: "Nebula Guardian",
      subtitle:
          "Anchor your orbit inside the deep cosmos. Deflect psychological chaos.",
      requiredStreak: 7,
      rewardIcon: Icons.shield_rounded,
      rewardName: "Advanced AI Lens Optics",
    ),
    JourneyMilestone(
      phase: "PHASE 4",
      title: "Quasar Sentinel",
      subtitle:
          "Emit pure steady energy into the void. A complete physical shift.",
      requiredStreak: 14,
      rewardIcon: Icons.looks_one_rounded,
      rewardName: "Premium Constellation Trail",
    ),
    JourneyMilestone(
      phase: "PHASE 5",
      title: "Supernova Absolute",
      subtitle:
          "Collapse old limits entirely. Your path illuminates the dark universe.",
      requiredStreak: 30,
      rewardIcon: Icons.workspace_premium_rounded,
      rewardName: "Orbit God-Tier Dashboard Pack",
    ),
  ];

  // Display metadata for the 5 Focus Journey categories — mirrors the
  // options in create_habit_sheet.dart's category picker and the palette
  // StellarPlanet already uses for the same variants.
  static const _focusJourneyCategories = [
    (
      value: 'fitness',
      label: 'Fitness',
      color: OrbitTokens.morning,
      variant: StellarPlanetVariant.fitness,
    ),
    (
      value: 'mind',
      label: 'Mind',
      color: OrbitTokens.violet,
      variant: StellarPlanetVariant.mind,
    ),
    (
      value: 'productivity',
      label: 'Productivity',
      color: OrbitTokens.teal,
      variant: StellarPlanetVariant.productivity,
    ),
    (
      value: 'growth',
      label: 'Growth',
      color: OrbitTokens.gold,
      variant: StellarPlanetVariant.growth,
    ),
    (
      value: 'core',
      label: 'Core',
      color: Color(0xFF3D5CFF),
      variant: StellarPlanetVariant.core,
    ),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ShareService.captureOffscreenWidget()/showShareBottomSheet() were fully
  // built (custom off-screen graphic rendering + a share sheet with native
  // share/post-to-X/copy/save-to-Photos) but had zero callers anywhere in
  // the app. This is the natural place for it: the screen that already
  // shows the streak/level header.
  Future<void> _shareStreak(BuildContext context) async {
    HapticFeedback.lightImpact();
    final routineProvider = context.read<RoutineProvider>();
    final telemetryProvider = context.read<TelemetryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final file = await ShareService.captureOffscreenWidget(
      ShareableStreakCard(
        streak: routineProvider.currentStreak,
        level: telemetryProvider.currentLevel,
      ),
      'orbit_streak',
    );

    if (!context.mounted) return;
    if (file == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not generate share image.')),
      );
      return;
    }

    ShareService.showShareBottomSheet(
      context: context,
      imageFile: file,
      shareText:
          "I'm on a ${routineProvider.currentStreak}-day streak in Orbit! 🚀",
    );
  }

  @override
  Widget build(BuildContext context) {
    final routineProvider = context.watch<RoutineProvider>();
    // Map unlocked states precisely to current active streak count
    final currentStreak = routineProvider.currentStreak;

    // Celebrate a Focus Journey hitting its final chapter — the XP was
    // already granted the moment RoutineProvider detected it (during the
    // daily-reset cycle); this just surfaces a one-time popup for it, then
    // clears the flag so it doesn't repeat on the next rebuild.
    final completedJourney = routineProvider.justCompletedJourney;
    if (completedJourney != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        routineProvider.acknowledgeJourneyCompletion();
        // The +150 XP this popup announces was only ever added to
        // RoutineProvider's spendable-currency pool, never through
        // TelemetryProvider.awardXp() -- so the Level bar right above this
        // celebration (which reads TelemetryProvider.globalXp) never moved,
        // making the reward this popup claims invisible everywhere except
        // as spendable currency.
        context.read<TelemetryProvider>().awardXp(
          RoutineProvider.journeyCompletionBonusXp,
        );
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: OrbitTokens.surface,
            behavior: SnackBarBehavior.floating,
            content: Text(
              '$completedJourney Journey Mastered! +${RoutineProvider.journeyCompletionBonusXp} XP',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      });
    }

    return Consumer<AtmosphereProvider>(
      builder: (context, atmosphere, child) {
        return Scaffold(
          backgroundColor: OrbitTokens.ground,
          body: Stack(
            children: [
              // Clean token ground with a faint ambient glow that shifts
              // with Cosmica's current aura (see AtmosphereProvider) —
              // violet by default, then whatever she "cast" on your last
              // habit completion.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: 1200.ms,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -1),
                        radius: 1.3,
                        colors: [
                          atmosphere.primaryGlow.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // LAYER 2: INTERACTIVE SCROLLING TIMELINE PATH
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 180.0,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.ios_share_rounded,
                          color: Colors.white70,
                        ),
                        tooltip: 'Share my streak',
                        onPressed: () => _shareStreak(context),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      title: const Text(
                        "Your Orbit Journey",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black54, Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Level pill + XP progress bar from the redesign pitch.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                      child: Consumer<TelemetryProvider>(
                        builder: (context, telemetry, _) {
                          final progress =
                              telemetry.levelProgressFraction.clamp(0.0, 1.0);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'MILESTONES',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: OrbitTokens.violet.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      'LV.${telemetry.currentLevel} VOYAGER',
                                      style: const TextStyle(
                                        color: OrbitTokens.violet,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 5,
                                      width: double.infinity,
                                      color: OrbitTokens.surface2,
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: progress,
                                      child: Container(
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          gradient: OrbitTokens.signal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${telemetry.globalXp} / ${telemetry.xpForNextLevel} XP to Level ${telemetry.currentLevel + 1}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  // Per-category "Focus Journey" chapter progress — a
                  // separate axis from the global streak milestones above,
                  // driven by RoutineProvider.categoryChapter/
                  // categoryChapterProgress (dormant unlockChapter/
                  // getUnlockedChapters storage, now actually wired to a
                  // trigger + UI).
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FOCUS JOURNEYS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._focusJourneyCategories.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final option = entry.value;
                            final chapter = routineProvider.categoryChapter(
                              option.value,
                            );
                            final progress = routineProvider
                                .categoryChapterProgress(option.value);
                            final isMastered =
                                chapter >= RoutineProvider.maxChapters;
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    index == _focusJourneyCategories.length - 1
                                    ? 0
                                    : 10,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: OrbitTokens.surface2.withValues(
                                    alpha: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: option.color.withValues(
                                      alpha: isMastered ? 0.6 : 0.2,
                                    ),
                                    width: isMastered ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    StellarPlanet(
                                      variant: option.variant,
                                      size: 36,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Text(
                                                option.label,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  if (isMastered) ...[
                                                    Icon(
                                                      Icons.star_rounded,
                                                      color: option.color,
                                                      size: 13,
                                                    ),
                                                    const SizedBox(width: 3),
                                                  ],
                                                  Text(
                                                    isMastered
                                                        ? 'Mastered'
                                                        : 'Chapter $chapter of ${RoutineProvider.maxChapters}',
                                                    style: TextStyle(
                                                      color: option.color,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: Stack(
                                              children: [
                                                Container(
                                                  height: 4,
                                                  width: double.infinity,
                                                  color: OrbitTokens.surface2,
                                                ),
                                                FractionallySizedBox(
                                                  widthFactor: progress,
                                                  child: Container(
                                                    height: 4,
                                                    color: option.color,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final milestone = _milestones[index];
                        final isUnlocked =
                            currentStreak >= milestone.requiredStreak;
                        // The first not-yet-unlocked milestone is "current":
                        // it gets the teal halo + days-progress treatment
                        // from the pitch instead of reading as merely locked.
                        final isCurrent = !isUnlocked &&
                            (index == 0 ||
                                currentStreak >=
                                    _milestones[index - 1].requiredStreak);

                        return UpgradedMilestoneCard(
                              index: index,
                              milestone: milestone,
                              isUnlocked: isUnlocked,
                              isCurrent: isCurrent,
                              currentStreak: currentStreak,
                              isLast: index == _milestones.length - 1,
                            )
                            .animate()
                            .fade(delay: (index * 100).ms)
                            .slideX(begin: index.isEven ? -0.05 : 0.05, end: 0);
                      }, childCount: _milestones.length),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
