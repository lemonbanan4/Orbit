import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

// Adjust this import path if your milestone detail screen is located elsewhere!
import '../stats/milestone_detail_screen.dart';

class PathDetailScreen extends StatelessWidget {
  final String pathTitle;
  final Color accentColor;

  const PathDetailScreen({
    super.key,
    required this.pathTitle,
    required this.accentColor,
  });

  // Simulated milestones for a path. You can eventually pull these from Firestore too!
  List<String> _getStepsForPath() {
    return [
      'Day 1: Getting Started',
      'Day 2: Finding Rhythm',
      'Day 3: Building Momentum',
      'Day 4: Pushing Through',
      'Day 5: The Final Stretch',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final steps = _getStepsForPath();
    const Color bgColor = Color(0xFF050112);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          pathTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          // --- BACKGROUND ORB ---
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.15),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.9, end: 1.1, duration: 6.seconds),
          ),

          SafeArea(
            child: user == null
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(color: accentColor),
                        );
                      }

                      final data =
                          snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final completedMilestones =
                          (data['completedMilestones'] as List<dynamic>?)
                                  ?.cast<String>() ??
                              [];

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: steps.length,
                        itemBuilder: (context, index) {
                          final step = steps[index];
                          final isCompleted = completedMilestones.contains(
                            step,
                          );

                          // Unlocked if it's completed, OR if it's the very first step, OR if the previous step is completed.
                          final isUnlocked = isCompleted ||
                              index == 0 ||
                              completedMilestones.contains(steps[index - 1]);

                          return _buildStepCard(
                            context,
                            step,
                            index + 1,
                            isCompleted,
                            isUnlocked,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(
    BuildContext context,
    String stepTitle,
    int stepNumber,
    bool isCompleted,
    bool isUnlocked,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MilestoneDetailScreen(
                stepTitle: stepTitle,
                isUnlocked: isUnlocked,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isCompleted
                    ? accentColor.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isCompleted
                      ? accentColor.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? accentColor
                          : isUnlocked
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black26,
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_rounded
                          : isUnlocked
                              ? Icons.play_arrow_rounded
                              : Icons.lock_rounded,
                      color: isCompleted
                          ? Colors.black
                          : isUnlocked
                              ? Colors.white
                              : Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step $stepNumber',
                          style: TextStyle(
                            color: isUnlocked ? accentColor : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stepTitle,
                          style: TextStyle(
                            color: isUnlocked ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fade(delay: (stepNumber * 50).ms).slideY(begin: 0.1),
    );
  }
}
