import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../services/cosmic_mirror_service.dart';
import '../../providers/routine_provider.dart';

class CosmicMirrorScreen extends StatefulWidget {
  const CosmicMirrorScreen({super.key});

  @override
  State<CosmicMirrorScreen> createState() => _CosmicMirrorScreenState();
}

class _CosmicMirrorScreenState extends State<CosmicMirrorScreen> {
  late Future<String> _legendFuture;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _fetchLegend();
      _isInitialized = true;
    }
  }

  void _fetchLegend() {
    final routineProvider = context.read<RoutineProvider>();
    final habits = routineProvider.habits.values.toList();

    final habitsDone = habits
        .where((h) => h.isCompleted)
        .map((h) => h.title)
        .toList();
    final habitsMissed = habits
        .where((h) => !h.isCompleted)
        .map((h) => h.title)
        .toList();

    final service = context.read<CosmicMirrorService>();
    _legendFuture = service.generateWeeklyLegend(habitsDone, habitsMissed);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/nebula_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white70,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: FutureBuilder<String>(
                      future: _legendFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildLoadingState();
                        }

                        final legendText =
                            snapshot.data ?? "Your stars are forming...";

                        return Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "THE COSMIC MIRROR",
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 40),

                              // THE LEGEND CARD
                              _buildLegendCard(legendText),

                              const SizedBox(height: 32),

                              // Share button
                              _buildShareButton(context, legendText),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendCard(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child:
          Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  fontFamily: 'Serif',
                ),
              )
              .animate()
              .fadeIn(duration: 2.seconds)
              .scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Colors.amberAccent),
        const SizedBox(height: 20),
        Text(
          "Consulting the constellations...",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _buildShareButton(BuildContext context, String legendText) {
    final streakCount = context.read<RoutineProvider>().currentStreak;

    return OutlinedButton.icon(
      onPressed: () {
        HapticFeedback.mediumImpact();
        SharePlus.instance.share(
          ShareParams(
            text:
                "I'm on a $streakCount-day streak in Orbit! Here is my Cosmic Legend:\n\n\"$legendText\"\n\nCan you beat my high score? 🚀",
            subject: 'My Orbit Progress',
          ),
        );
      },
      icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
      label: const Text(
        "SHARE MY LEGEND",
        style: TextStyle(color: Colors.white),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.amberAccent),
      ),
    );
  }
}

void showCosmicMirror(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CosmicMirrorScreen()),
  );
}
