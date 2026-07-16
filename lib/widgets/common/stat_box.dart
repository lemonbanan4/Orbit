import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/orbit_colors.dart';

class StatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final int delay;

  const StatBox({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ??
        Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: resolvedColor, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    ).animate().fade(delay: delay.ms).slideY(begin: 0.2);
  }
}
