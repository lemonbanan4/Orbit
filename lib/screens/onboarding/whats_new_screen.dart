import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/feature_row.dart';
import '../../widgets/common/primary_button.dart';
import '../navigation/main_navigation_screen.dart';
import '../../theme/orbit_tokens.dart';

class WhatsNewScreen extends StatelessWidget {
  final String currentVersion;

  const WhatsNewScreen({super.key, required this.currentVersion});

  Future<void> _continue(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_seen_version', currentVersion);

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitTokens.ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch_rounded,
                      size: 80, color: OrbitTokens.teal)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: -10, end: 10, duration: 2.seconds),
              const SizedBox(height: 32),
              const Text(
                "What's New in Orbit",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ).animate().fade().slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                "Version $currentVersion",
                style: const TextStyle(
                    color: OrbitTokens.teal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2),
              ).animate().fade(delay: 200.ms),
              const SizedBox(height: 48),
              const FeatureRow(
                  icon: Icons.bolt_rounded,
                  color: Colors.amberAccent,
                  title: 'Live Activities',
                  subtitle:
                      'Track today\'s progress right from your Lock Screen and Dynamic Island.',
                  delay: 400),
              const SizedBox(height: 24),
              const FeatureRow(
                  icon: Icons.block_rounded,
                  color: Colors.redAccent,
                  title: 'Quit a Habit',
                  subtitle:
                      'New "Something to Avoid" habits start each day already won — tap only if you slip.',
                  delay: 600),
              const SizedBox(height: 24),
              const FeatureRow(
                  icon: Icons.groups_rounded,
                  color: Colors.tealAccent,
                  title: 'Group Challenges',
                  subtitle:
                      'Invite friends into a shared challenge and check in together.',
                  delay: 800),
              const SizedBox(height: 24),
              const FeatureRow(
                  icon: Icons.favorite_rounded,
                  color: Colors.pinkAccent,
                  title: 'Apple Health & Health Connect',
                  subtitle:
                      'Link steps, workouts, and more so habits complete themselves.',
                  delay: 1000),
              const Spacer(),
              PrimaryButton(
                text: 'Continue to App',
                onPressed: () => _continue(context),
              )
                  .animate()
                  .fade(delay: 1000.ms)
                  .scaleXY(begin: 0.9, end: 1.0, curve: Curves.easeOutBack),
            ],
          ),
        ),
      ),
    );
  }
}
