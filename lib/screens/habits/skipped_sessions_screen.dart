import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/premium_glass_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../../theme/orbit_colors.dart';

class SkippedSessionsScreen extends StatefulWidget {
  const SkippedSessionsScreen({super.key});

  @override
  State<SkippedSessionsScreen> createState() => _SkippedSessionsScreenState();
}

class _SkippedSessionsScreenState extends State<SkippedSessionsScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final orbitColors = theme.extension<OrbitColors>();
    final orbColor1 = orbitColors?.orbColor1 ?? const Color(0xFF00E5FF);
    final orbColor2 = orbitColors?.orbColor2 ?? const Color(0xFF7000FF);

    return BaseOrbitScreen(
      title: 'Skipped Sessions',
      body: Stack(
        children: [
          user == null
              ? const Center(child: Text('Not logged in.'))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('skipped_sessions')
                      .orderBy('timestamp', descending: true)
                      // No retention cleanup on this collection and this
                      // listener had no cap -- a long-time user's entire
                      // skip history got read and held on every visit.
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child: CircularProgressIndicator(
                              color: orbColor1));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No skipped sessions. Your orbit is flawless!',
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.5)),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final title =
                            data['habitTitle'] as String? ?? 'Unknown Habit';
                        final reason =
                            data['reason'] as String? ?? 'No reason provided';
                        final timestamp = data['timestamp'] as Timestamp?;
                        final dateStr = timestamp != null
                            ? _formatDate(timestamp.toDate())
                            : 'Unknown Date';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: PremiumGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 16),
                                          ),
                                          Text(
                                            dateStr,
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: Colors.greenAccent),
                                      tooltip: 'I made up for it!',
                                      onPressed: () async {
                                        HapticFeedback.mediumImpact();
                                        _confettiController.play();
                                        await Future.delayed(
                                            const Duration(milliseconds: 600));
                                        if (!mounted) return;
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user.uid)
                                              .collection('skipped_sessions')
                                              .doc(docs[index].id)
                                              .delete();
                                        } catch (e) {
                                          debugPrint(
                                              'Failed to clear skipped session: $e');
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Could not clear this session. Please try again.'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '"$reason"',
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          )
                              .animate()
                              .fade(delay: (index * 50).ms)
                              .slideX(begin: 0.1),
                        );
                      },
                    );
                  },
                ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                gravity: 0.2,
                colors: [
                  orbColor1,
                  orbColor2,
                  Colors.white,
                  theme.colorScheme.primary,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
