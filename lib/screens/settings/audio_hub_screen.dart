import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/routine_provider.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../paywall/premium_checker.dart';

class AudioHubScreen extends StatefulWidget {
  const AudioHubScreen({super.key});

  @override
  State<AudioHubScreen> createState() => _AudioHubScreenState();
}

class _AudioHubScreenState extends State<AudioHubScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _panController;

  @override
  void initState() {
    super.initState();
    _panController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    // Stop ambient audio when leaving the Audio Hub
    context.read<RoutineProvider>().stopAmbientAudio();
    _scrollController.dispose();
    _panController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routineProvider = context.watch<RoutineProvider>();
    final isPlaying = routineProvider.isPlayingAmbient;
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final bool isDark = theme.brightness == Brightness.dark;

    // Simulated Premium Tracks
    final List<Map<String, dynamic>> tracks = [
      {
        'title': 'Space Hum',
        'subtitle': 'Deep focus frequency',
        'icon': Icons.waves_rounded,
        'path': 'assets/audio/hypnotic_loop.mp3',
        'pro': false,
      },
      {
        'title': 'Nebula Drift',
        'subtitle': 'Binaural beats for reading',
        'icon': Icons.bubble_chart_rounded,
        'path': 'assets/audio/nebula_drift.mp3',
        'pro': true,
      },
      {
        'title': 'Solar Flare',
        'subtitle': 'High energy workout',
        'icon': Icons.local_fire_department_rounded,
        'path': 'assets/audio/solar_flare.mp3',
        'pro': true,
      },
      {
        'title': 'Lunar Rest',
        'subtitle': 'Delta waves for sleep',
        'icon': Icons.nightlight_round,
        'path': 'assets/audio/lunar_rest.mp3',
        'pro': true,
      },
    ];

    return BaseOrbitScreen(
      title: 'Cosmic Audio',
      body: Stack(
        children: [
          // THE PARALLAX BACKGROUND LAYER
          AnimatedBuilder(
            animation: Listenable.merge([_scrollController, _panController]),
            builder: (context, child) {
              // Calculate the parallax offset
              double parallaxOffset = 0.0;
              if (_scrollController.hasClients) {
                parallaxOffset = _scrollController.offset * -0.1;
              }
              // Calculate auto-panning offset
              double panOffset = (_panController.value - 0.5) * 50;
              return Positioned(
                top: -50 + parallaxOffset,
                left: -50 + panOffset,
                right: -50 - panOffset,
                bottom: -50,
                child: Opacity(
                  opacity: isDark ? 0.4 : 0.1,
                  child: Image.asset(
                    'assets/images/nebula_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // --- HEADER VISUALIZER ---
                    Center(
                      child:
                          Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF00E5FF,
                                  ).withValues(alpha: 0.1),
                                  boxShadow: isPlaying
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF00E5FF,
                                            ).withValues(alpha: 0.3),
                                            blurRadius: 40,
                                            spreadRadius: 10,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Icon(
                                  isPlaying
                                      ? Icons.graphic_eq_rounded
                                      : Icons.headphones_rounded,
                                  size: 64,
                                  color: const Color(0xFF00E5FF),
                                ),
                              )
                              .animate(target: isPlaying ? 1 : 0)
                              .scaleXY(end: 1.1, duration: 1.seconds)
                              .shimmer(duration: 2.seconds),
                    ),
                    const SizedBox(height: 40),

                    // --- MASTER TOGGLE ---
                    PremiumGlassCard(
                      child: SwitchListTile(
                        title: const Text(
                          'Master Audio',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          'Toggle ambient background audio',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        value: isPlaying,
                        activeThumbColor: const Color(0xFF00E5FF),
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          routineProvider.toggleAmbientAudio();
                        },
                      ),
                    ).animate().fade().slideY(begin: 0.1),

                    const SizedBox(height: 32),
                    Text(
                      'Soundscapes',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.9),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fade(delay: 100.ms),
                    const SizedBox(height: 16),

                    // --- TRACK LIST ---
                    ...tracks.map((track) {
                      final bool isSelected =
                          routineProvider.selectedAudioTrack == track['path'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: PremiumGlassCard(
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(
                                        0xFF00E5FF,
                                      ).withValues(alpha: 0.3)
                                    : const Color(
                                        0xFF00E5FF,
                                      ).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                track['icon'],
                                color: const Color(0xFF00E5FF),
                              ),
                            ),
                            title: Text(
                              track['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              track['subtitle'],
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            trailing: isSelected && isPlaying
                                ? const Icon(
                                    Icons.graphic_eq_rounded,
                                    color: Color(0xFF00E5FF),
                                  )
                                : track['pro']
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orangeAccent.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.orangeAccent.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              void playSelectedTrack() {
                                routineProvider.setAmbientTrack(track['path']);
                                if (!routineProvider.isPlayingAmbient) {
                                  routineProvider.toggleAmbientAudio();
                                }
                              }

                              if (track['pro']) {
                                PremiumChecker.requirePro(
                                  context,
                                  onAccessGranted: playSelectedTrack,
                                );
                              } else {
                                playSelectedTrack();
                              }
                            },
                          ),
                        ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
                      );
                    }),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
