import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/journey_milestone.dart';
import '../../widgets/common/premium_glass_card.dart';

class JourneyTimelineScreen extends StatelessWidget {
  final List<JourneyMilestone> milestones;

  const JourneyTimelineScreen({super.key, required this.milestones});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050112), // Deep Orbit Void
      appBar: AppBar(
        title:
            const Text("Your Journey", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // MEET YOUR FUTURE SELF CARD (Image 5)
              _buildFutureSelfHeader(),
              const SizedBox(height: 32),
              // THE ROADMAP (The dot-line)
              _buildTimelineList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFutureSelfHeader() {
    return Container(
      padding: const EdgeInsets.all(2), // Border Width
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32), // Match glass card + padding
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00E5FF),
            Color(0xFF7000FF),
            Colors.amber,
            Color(0xFF00E5FF)
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: PremiumGlassCard(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF00E5FF),
                size: 32,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.9, end: 1.1, duration: 2.seconds),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meet Your Future Self',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Every milestone you conquer brings you one step closer to the best version of yourself.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 3.seconds, color: Colors.white24)
        .animate()
        .fade(duration: 800.ms)
        .slideY(begin: 0.2);
  }

  Widget _buildTimelineList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: milestones.length,
      itemBuilder: (context, index) {
        final milestone = milestones[index];
        final isLast = index == milestones.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. THE LINE & DOTS (The vertical roadmap track)
            _buildTimelineMarker(isLast, milestone.isCompleted),
            const SizedBox(width: 24),
            // 2. THE MILESTONE ICON & TEXT (Image 4/2)
            _buildMilestoneContent(milestone),
          ],
        );
      },
    );
  }

  // --- WIDGET BUILDER: Marker Line ---
  Widget _buildTimelineMarker(bool isLast, bool isCompleted) {
    final color = isCompleted ? const Color(0xFF00E5FF) : Colors.white30;

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color:
                isCompleted ? color.withValues(alpha: 0.2) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: isCompleted
              ? const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Color(0xFF00E5FF),
                )
              : null,
        ),
        if (!isLast)
          Container(
            width: 2,
            height: 40,
            color: color.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  // --- WIDGET BUILDER: Content (Text & the actual Icon) ---
  Widget _buildMilestoneContent(JourneyMilestone milestone) {
    final color = milestone.isCompleted ? Colors.white : Colors.white60;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32.0, top: 2.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              milestone.title,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                decoration:
                    milestone.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              milestone.description,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
