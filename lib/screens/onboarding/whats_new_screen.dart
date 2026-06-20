import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/feature_row.dart';
import '../navigation/main_navigation_screen.dart';

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
      backgroundColor: const Color(0xFF050112),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch_rounded,
                      size: 80, color: Color(0xFF00E5FF))
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
                    color: Color(0xFF00E5FF),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2),
              ).animate().fade(delay: 200.ms),
              const SizedBox(height: 48),
              const FeatureRow(
                  icon: Icons.monitor_heart_rounded,
                  color: Colors.redAccent,
                  title: 'Apple Health Sync',
                  subtitle:
                      'Automate your workout habits seamlessly in the background.',
                  delay: 400),
              const SizedBox(height: 24),
              const FeatureRow(
                  icon: Icons.notifications_active_rounded,
                  color: Colors.amber,
                  title: 'Notifications Inbox',
                  subtitle:
                      'A dedicated inbox and archive to ensure you never miss a reward.',
                  delay: 600),
              const SizedBox(height: 24),
              const FeatureRow(
                  icon: Icons.app_shortcut_rounded,
                  color: Colors.purpleAccent,
                  title: 'Orbit Pro Icons',
                  subtitle:
                      'Customize your home screen with premium app icons.',
                  delay: 800),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _continue(context),
                  child: const Text('Continue to App',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
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
