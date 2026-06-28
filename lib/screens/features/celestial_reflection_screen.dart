// lib/screens/coaching/cosmic_mirror_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../services/cosmic_mirror_service.dart';
import '../../../providers/routine_provider.dart';

class CelestialReflectionScreen extends StatefulWidget {
  const CelestialReflectionScreen({super.key});

  @override
  State<CelestialReflectionScreen> createState() =>
      _CelestialReflectionScreenState();
}

class _CelestialReflectionScreenState extends State<CelestialReflectionScreen> {
  late Future<String> _reflectionPromptFuture;
  final TextEditingController _responseController = TextEditingController();
  bool _isInitialized = false;
  bool _isForging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _fetchDailyData();
      _isInitialized = true;
    }
  }

  void _fetchDailyData() {
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
    _reflectionPromptFuture = service.generateDailyReflectionPrompt(
      habitsDone,
      habitsMissed,
    );
  }

  void _forgeReflection() async {
    if (_responseController.text.trim().isEmpty) return;

    setState(() => _isForging = true);
    HapticFeedback.heavyImpact();

    // Simulated cosmic compilation (save this data to local storage or Firebase later!)
    await Future.delayed(1500.ms);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Reflection fused into the cosmos. Alignment updated! 🌌",
          ),
          backgroundColor: Colors.deepPurple,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Cosmic Veil
          Positioned.fill(
            child: Image.asset(
              'assets/images/nebula_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white60,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "CELESTIAL REFLECTION",
                    style: TextStyle(
                      color: Colors.amberAccent,
                      letterSpacing: 4,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

                  FutureBuilder<String>(
                    future: _reflectionPromptFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState();
                      }
                      final promptText =
                          snapshot.data ?? "The mirror is clouding...";

                      return Column(
                        children: [
                          // Dynamic Oracle Prompt Card
                          _buildGlassCard(promptText),
                          const SizedBox(height: 35),

                          // Text Input Box
                          _buildInputBox(),
                          const SizedBox(height: 30),

                          // Forge Button
                          _buildForgeButton(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        "\"$text\"",
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontStyle: FontStyle.italic,
          height: 1.5,
          fontFamily: 'Serif',
        ),
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildInputBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: _responseController,
        maxLines: 5,
        maxLength: 250,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: const InputDecoration(
          hintText: "Speak your truth to the dark expanse...",
          hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(20),
          counterStyle: TextStyle(color: Colors.white30),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 600.ms);
  }

  Widget _buildForgeButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: _isForging ? null : _forgeReflection,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.amberAccent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.amberAccent.withValues(
            alpha: _isForging ? 0.0 : 0.05,
          ),
        ),
        child: _isForging
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.amberAccent,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "FORGE MY ALIGNMENT",
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80.0),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.amberAccent),
          const SizedBox(height: 24),
          Text(
            "Consulting the constellations...",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
