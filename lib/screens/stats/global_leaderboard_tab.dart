import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/premium_glass_card.dart';

class GlobalLeaderboardTab extends StatelessWidget {
  const GlobalLeaderboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('xp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading leaderboard.',
                style: TextStyle(color: textColor)),
          );
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return Center(
            child:
                Text('No explorers found.', style: TextStyle(color: textColor)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final name = userData['displayName'] ?? 'Commander';
            final xp = userData['xp'] ?? 0;
            final formattedXp =
                xp.toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',');
            final streak = userData['current_streak'] ?? 0;
            final isMe = currentUser?.uid == users[index].id;

            Color rankColor;
            if (index == 0) {
              rankColor = Colors.amber;
            } else if (index == 1) {
              rankColor = Colors.blueGrey.shade300;
            } else if (index == 2) {
              rankColor = Colors.deepOrangeAccent;
            } else {
              rankColor = textColor.withValues(alpha: 0.5);
            }

            Widget card = PremiumGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        color: rankColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: isMe
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                        : Colors.white10,
                    child: Icon(Icons.person,
                        color: isMe ? const Color(0xFF00E5FF) : Colors.white54),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: isMe ? const Color(0xFF00E5FF) : textColor,
                            fontWeight:
                                isMe ? FontWeight.w900 : FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            if (streak >= 3)
                              const Padding(
                                padding: EdgeInsets.only(right: 4.0),
                                child: Icon(Icons.local_fire_department_rounded,
                                    color: Colors.orangeAccent, size: 14),
                              ),
                            Text(
                              '$streak Day Streak',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$formattedXp XP',
                    style: const TextStyle(
                      color: Color(0xFF7000FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );

            if (index == 0) {
              card = card
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.02, duration: 1.seconds)
                  .boxShadow(
                    begin: const BoxShadow(color: Colors.transparent),
                    end: BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                    duration: 1.seconds,
                  );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: card,
            ).animate().fade(delay: (index * 50).ms, duration: 400.ms).slideY(
                  begin: 0.1,
                );
          },
        );
      },
    );
  }
}
