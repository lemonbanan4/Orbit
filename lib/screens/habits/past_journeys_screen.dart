import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../../widgets/common/journey_card.dart';
import 'package:audioplayers/audioplayers.dart';

class PastJourneysScreen extends StatelessWidget {
  const PastJourneysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF050112), // Premium dark theme bg
      appBar: AppBar(
        title: const Text('Past Journeys',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
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
                          CircularProgressIndicator(color: Color(0xFF00E5FF)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Filter for fully completed habits
                final completedHabits = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final completed = data['completedDays'] as int? ?? 0;
                  final total = data['totalDays'] as int? ?? 7;
                  return completed >= total && total > 0;
                }).toList();

                if (completedHabits.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: completedHabits.length,
                  itemBuilder: (context, index) {
                    final data =
                        completedHabits[index].data() as Map<String, dynamic>;
                    final title = data['path'] as String? ?? 'Unknown Journey';
                    final total = data['totalDays'] as int? ?? 7;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: JourneyCard(
                        title: title,
                        subtitle: '$total-Day Journey Completed',
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
                            AudioPlayer()
                                .play(AssetSource('audio/success_chime.mp3'));
                            final habitId =
                                title.toLowerCase().replaceAll(' ', '_');
                            final userRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid);

                            await userRef.update({
                              'interests': FieldValue.arrayUnion([title])
                            });
                            await userRef
                                .collection('habits')
                                .doc(habitId)
                                .update({
                              'completedDays': 0,
                              'completedDates': [],
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Journey Restarted! 🚀'),
                                    backgroundColor: Colors.green),
                              );
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
