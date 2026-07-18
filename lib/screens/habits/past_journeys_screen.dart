import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../../widgets/common/journey_card.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../theme/orbit_tokens.dart';

class PastJourneysScreen extends StatelessWidget {
  const PastJourneysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: OrbitTokens.ground,
      appBar: AppBar(
        title: const Text('Past Journeys',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(color: OrbitTokens.teal))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('habits')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: OrbitTokens.teal));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Filter for fully completed habits.
                //
                // totalDays used to be a fixed goal seeded at creation
                // (21/7 days) that never changed, so `completed >= total`
                // meant "hit every day of the actual goal." It's now a
                // running "days tracked" tally that increments alongside
                // completedDays every single day (see RoutineProvider's
                // _checkDailyReset self-heal) -- for any never-skipped
                // habit, completed == total from day one, which silently
                // archived every actively-succeeding habit as "complete"
                // immediately. 21 completions is the app's own established
                // "habit formed" threshold (the old seed value this
                // replaced).
                final completedHabits = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final completed = data['completedDays'] as int? ?? 0;
                  return completed >= 21;
                }).toList();

                if (completedHabits.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: completedHabits.length,
                  itemBuilder: (context, index) {
                    final habitDoc = completedHabits[index];
                    final data = habitDoc.data() as Map<String, dynamic>;
                    // Habit.toMap() writes 'title', not 'path' — 'path' is
                    // never a real field, so this always fell back to
                    // "Unknown Journey" for every entry.
                    final title = data['title'] as String? ?? 'Unknown Journey';
                    final completed = data['completedDays'] as int? ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: JourneyCard(
                        title: title,
                        subtitle: '$completed-Day Journey Completed',
                        progress: 1.0,
                        icon: Icons.check_circle_rounded,
                        accentColor: Colors.purpleAccent,
                        onTap: () {},
                        trailing: IconButton(
                          icon: const Icon(Icons.restart_alt_rounded,
                              color: Colors.amber, size: 28),
                          tooltip: 'Restart Journey',
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final userRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid);

                            try {
                              AudioPlayer().play(
                                  AssetSource('audio/success_chime.mp3'));
                              await userRef.update({
                                'interests': FieldValue.arrayUnion([title])
                              });
                              // Use the real habit doc id from the snapshot —
                              // deriving one from the (broken) title used to
                              // target a document that never existed.
                              await userRef
                                  .collection('habits')
                                  .doc(habitDoc.id)
                                  .update({
                                'completedDays': 0,
                                'totalDays': 0,
                                'skippedCount': 0,
                              });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Journey Restarted! 🚀'),
                                      backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Could not restart: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    )
                        .animate()
                        .fade(delay: (index * 100).ms)
                        .slideY(begin: 0.1);
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.white24),
          SizedBox(height: 24),
          Text('No Past Journeys Yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text(
              'When you fully complete a focus area,\nit will be archived here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    ).animate().fade();
  }
}
