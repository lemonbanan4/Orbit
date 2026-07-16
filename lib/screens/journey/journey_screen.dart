import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:orbit_app/providers/atmosphere_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/routine_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../widgets/journey/upgraded_milestone_card.dart';
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
  double _scrollOffset = 0;

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routineProvider = context.watch<RoutineProvider>();
    // Map unlocked states precisely to current active streak count
    final currentStreak = routineProvider.currentStreak;

    return Consumer<AtmosphereProvider>(
      builder: (context, atmosphere, child) {
        return Scaffold(
          backgroundColor: OrbitTokens.ground,
          body: Stack(
            children: [
              // LAYER 1: PARALLAX NEBULA
              Positioned(
                top: -(_scrollOffset * 0.25),
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: 0.18,
                  child: Image.asset(
                    'assets/images/contract_bg.png',
                    fit: BoxFit.cover,
                    height: MediaQuery.of(context).size.height * 1.0,
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

                        return UpgradedMilestoneCard(
                              index: index,
                              milestone: milestone,
                              isUnlocked: isUnlocked,
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
