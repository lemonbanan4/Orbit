import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoutineAppBar extends StatelessWidget {
  final String routineType;
  final List<Color> gradientColors;

  const RoutineAppBar({
    super.key,
    required this.routineType,
    required this.gradientColors,
  });

  IconData _getIcon() {
    switch (routineType) {
      case 'Morning':
        return Icons.wb_sunny_rounded;
      case 'Work':
        return Icons.work_rounded;
      case 'Night':
        return Icons.nightlight_round;
      default:
        return Icons.explore_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: gradientColors.last, // Match the bottom of the gradient
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  _getIcon(),
                  size: 160,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
