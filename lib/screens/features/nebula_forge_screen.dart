// lib/screens/features/nebula_forge_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/orbit_tokens.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import '../../services/alchemy_telemetry_service.dart';

class NebulaForgeScreen extends StatelessWidget {
  final String sourcePhase;

  const NebulaForgeScreen({super.key, this.sourcePhase = "Live Matrix"});

  @override
  Widget build(BuildContext context) {
    final routineProvider = context.watch<RoutineProvider>();
    final currentHabits = routineProvider.habits.values.toList();
    final synergyList = AlchemyTelemetryService.computeSynergyMatrix(
      currentHabits,
    );

    return Scaffold(
      body: Stack(
        children: [
          // Background Cosmic Canvas
          Positioned.fill(
            child: Image.asset(
              'assets/images/nebula_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(color: Colors.black.withValues(alpha: 0.65)),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom Header Panel
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sourcePhase.toUpperCase(),
                            style: const TextStyle(
                              color: OrbitTokens.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            "THE NEBULA FORGE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Core Telemetry Output Streams
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    itemCount: synergyList.length,
                    itemBuilder: (context, index) {
                      final item = synergyList[index];
                      return _buildSynergyFusionCard(item, index);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSynergyFusionCard(HabitSynergy item, int index) {
    final bool isHighSynergy = item.synergyPercentage >= 75.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Habit Element Pairs Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.blur_circular_rounded,
                            color: Colors.amberAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${item.habitA} ⇄ ${item.habitB}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "${item.synergyPercentage}%",
                      style: TextStyle(
                        color: isHighSynergy
                            ? OrbitTokens.teal
                            : Colors.purpleAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Premium Linear Track bar
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (item.synergyPercentage / 100.0).clamp(
                        0.0,
                        1.0,
                      ),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            colors: isHighSynergy
                                ? [OrbitTokens.teal, Colors.blueAccent]
                                : [Colors.purpleAccent, Colors.deepPurple],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Algorithmic Verdict Block
                Text(
                  item.cosmicVerdict,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 150).ms).slideY(begin: 0.1, end: 0);
  }
}
