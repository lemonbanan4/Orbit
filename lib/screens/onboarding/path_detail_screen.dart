import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';

class PathDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const PathDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  State<PathDetailScreen> createState() => _PathDetailScreenState();
}

class _PathDetailScreenState extends State<PathDetailScreen> {
  late ConfettiController _confettiController;
  final GlobalKey _stackKey = GlobalKey();
  Offset? _confettiOrigin;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              key: _stackKey,
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final data = snapshot.data?.data() as Map<String, dynamic>?;
                    final completedMilestones =
                        (data?['completedMilestones'] as List<dynamic>?)
                                ?.cast<String>() ??
                            [];

                    final List<String> steps = [
                      'Day 1: Getting Started',
                      'Day 2: Finding Rhythm',
                      'Day 3: Building Momentum',
                      'Day 4: Pushing Through',
                      'Day 5: The Final Stretch',
                    ];

                    // Calculate dynamic progress based on completed steps
                    int completedCount = steps
                        .where((step) => completedMilestones.contains(step))
                        .length;
                    double dynamicProgress =
                        steps.isEmpty ? 0.0 : completedCount / steps.length;

                    return ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // Header Graphic
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1A1F36,
                              ).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Hero(
                              tag: widget.title,
                              child: Icon(
                                widget.icon,
                                color: const Color(0xFF1A1F36),
                                size: 64,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1F36),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            widget.subtitle,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Progress Section
                        const Text(
                          'Your Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1F36),
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: dynamicProgress,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          color: const Color(0xFF1A1F36),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 32),

                        // Path Milestones
                        const Text(
                          'Milestones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1F36),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...steps.asMap().entries.map((entry) {
                          int index = entry.key;
                          String step = entry.value;
                          bool isCompleted = completedMilestones.contains(step);
                          // Unlocked if it's completed, if it's the first step, or if the previous step is completed
                          bool isUnlocked = isCompleted ||
                              index == 0 ||
                              completedMilestones.contains(steps[index - 1]);
                          bool isFinalStep = index == steps.length - 1;

                          return _buildMilestoneCard(
                            context,
                            step,
                            isCompleted,
                            isUnlocked,
                            isFinalStep,
                          );
                        }),
                      ],
                    );
                  },
                ),
                Positioned(
                  left: _confettiOrigin?.dx ??
                      MediaQuery.of(context).size.width / 2,
                  top: _confettiOrigin?.dy ?? 0,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    emissionFrequency: 0.05,
                    numberOfParticles: 25,
                    gravity: 0.1,
                    colors: const [
                      Colors.green,
                      Colors.blue,
                      Colors.pink,
                      Colors.orange,
                      Colors.purple,
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMilestoneCard(
    BuildContext context,
    String stepTitle,
    bool isCompleted,
    bool isUnlocked,
    bool isFinalStep,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) {
        final RenderBox? box =
            _stackKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          setState(() {
            _confettiOrigin = box.globalToLocal(details.globalPosition);
          });
        }
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFF1A1F36)
                : (isUnlocked
                    ? const Color(0xFF1A1F36).withValues(alpha: 0.5)
                    : Colors.grey[200]),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted
                ? Icons.check
                : (isUnlocked
                    ? Icons.play_arrow_rounded
                    : Icons.lock_outline_rounded),
            color: isCompleted || isUnlocked ? Colors.white : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          stepTitle,
          style: TextStyle(
            fontWeight:
                isCompleted || isUnlocked ? FontWeight.bold : FontWeight.normal,
            color: isCompleted || isUnlocked
                ? const Color(0xFF1A1F36)
                : Colors.grey,
            fontSize: 16,
          ),
        ),
        trailing: isUnlocked
            ? const Icon(Icons.chevron_right_rounded, color: Color(0xFF1A1F36))
            : null,
        // onTap: () async {
        //   final result = await Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //       builder: (context) => MilestoneDetailScreen(
        //         stepTitle: stepTitle,
        //         isUnlocked: isUnlocked,
        //       ),
        //     ),
        //   );

        //   // If the user just completed the milestone and it was the final one, blast confetti!
        //   if (result == true && isFinalStep && context.mounted) {
        //     _confettiController.play();
        //   }
        // },
      ),
    );
  }
}
