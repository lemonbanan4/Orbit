import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WhatsNewPopup extends StatelessWidget {
  const WhatsNewPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1F36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.rocket_launch_rounded, color: Color(0xFF00E5FF)),
          SizedBox(width: 12),
          Text(
            "What's New in Orbit",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureRow(
            Icons.auto_stories,
            'Scroll of Wisdom',
            'Unlock daily motivational scrolls and earn the Sage Badge.',
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            Icons.group_add_rounded,
            'Partner Linking',
            'Connect your orbit with a friend to share XP and progress.',
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Awesome!',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ).animate().scaleXY(
        begin: 0.8, end: 1.0, duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 4),
              Text(description,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
