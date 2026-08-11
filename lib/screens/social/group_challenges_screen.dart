import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/orbit_colors.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import 'create_challenge_screen.dart';

class GroupChallengesScreen extends StatelessWidget {
  const GroupChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accent =
        Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);

    return BaseOrbitScreen(
      title: 'Group Challenges',
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateChallengeScreen(),
            ),
          );
        },
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: StreamBuilder<List<GroupChallenge>>(
        stream: ChallengeService.myChallenges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: accent));
          }
          final challenges = snapshot.data ?? [];
          if (challenges.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No challenges yet -- invite friends into a shared '
                  'commitment and hold each other accountable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            physics: const BouncingScrollPhysics(),
            itemCount: challenges.length,
            itemBuilder: (context, index) =>
                _ChallengeCard(challenge: challenges[index]),
          );
        },
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final GroupChallenge challenge;
  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final accent =
        Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final daysLeft = challenge.endDate.difference(DateTime.now()).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PremiumGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    challenge.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: challenge.isActive
                        ? accent.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    challenge.isActive ? '$daysLeft days left' : 'Ended',
                    style: TextStyle(
                      color: challenge.isActive ? accent : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (challenge.goal.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                challenge.goal,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
            const SizedBox(height: 16),
            StreamBuilder<List<ChallengeProgress>>(
              stream: ChallengeService.progressFor(challenge.id),
              builder: (context, snap) {
                final progressByUid = {
                  for (final p in snap.data ?? <ChallengeProgress>[])
                    p.userId: p,
                };
                final myProgress = currentUserId == null
                    ? null
                    : progressByUid[currentUserId];
                final checkedInToday =
                    myProgress?.isCheckedInOn(DateTime.now()) ?? false;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where(
                        FieldPath.documentId,
                        whereIn: challenge.participantIds.length > 30
                            ? challenge.participantIds.sublist(0, 30)
                            : challenge.participantIds,
                      )
                      .snapshots(),
                  builder: (context, usersSnap) {
                    final names = <String, String>{
                      for (final doc in usersSnap.data?.docs ?? [])
                        doc.id:
                            (doc.data() as Map<String, dynamic>)['name']
                                ?.toString() ??
                            'Explorer',
                    };
                    final ranked = challenge.participantIds.toList()
                      ..sort((a, b) {
                        final aCount = progressByUid[a]?.checkinCount ?? 0;
                        final bCount = progressByUid[b]?.checkinCount ?? 0;
                        return bCount.compareTo(aCount);
                      });

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final uid in ranked)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    uid == currentUserId
                                        ? 'You'
                                        : (names[uid] ?? 'Explorer'),
                                    style: TextStyle(
                                      color: uid == currentUserId
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: uid == currentUserId
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${progressByUid[uid]?.checkinCount ?? 0}/${challenge.totalDays}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (challenge.isActive && currentUserId != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                ChallengeService.setTodayCheckin(
                                  challenge.id,
                                  !checkedInToday,
                                );
                              },
                              icon: Icon(
                                checkedInToday
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: checkedInToday ? accent : Colors.white54,
                                size: 18,
                              ),
                              label: Text(
                                checkedInToday
                                    ? "Checked in today"
                                    : "Check in for today",
                                style: TextStyle(
                                  color: checkedInToday
                                      ? accent
                                      : Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: checkedInToday
                                      ? accent
                                      : Colors.white.withValues(alpha: 0.2),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
