import 'package:flutter/material.dart';
import '../../theme/orbit_colors.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../common/add_friend_screen.dart';
import '../common/friend_requests_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _confirmRemoveFriend(String friendUid, String friendName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend?'),
        content: Text(
          "$friendName will be removed from your orbit. You'll need a new invite to reconnect.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('removeFriend')
          .call({'friendUid': friendUid});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $friendName.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to remove friend: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700); // Gold
    if (rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    // Everyone below the podium takes the theme accent.
    return Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final accent =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isDark = theme.brightness == Brightness.dark;

    return BaseOrbitScreen(
      title: 'Friends Leaderboard',
      actions: [
        if (currentUserId != null)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .collection('friend_requests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final pendingCount = snapshot.data?.docs.length ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text(pendingCount.toString()),
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    color: textColor,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FriendRequestsScreen(),
                    ),
                  );
                },
              );
            },
          ),
        IconButton(
          icon: Icon(Icons.person_add_alt_1_rounded, color: textColor),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddFriendScreen()),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: textColor),
          onPressed: () {
            HapticFeedback.lightImpact();
            // Tapping forces a rebuild which triggers the StreamBuilder
            (context as Element).markNeedsBuild();
          },
        ),
      ],
      body: Stack(
        children: [
          // THE PARALLAX BACKGROUND LAYER
          AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              // Calculate the parallax offset
              double parallaxOffset = 0.0;
              if (_scrollController.hasClients) {
                parallaxOffset = _scrollController.offset * -0.1;
              }
              return Positioned(
                top: -50 + parallaxOffset,
                left: -10,
                right: -10,
                bottom: -50,
                child: Opacity(
                  opacity: isDark ? 0.4 : 0.1,
                  child: Image.asset(
                    'assets/images/nebula_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
          if (currentUserId == null)
            Center(
              child: Text('Please log in.', style: TextStyle(color: textColor)),
            )
          else
            StreamBuilder<DocumentSnapshot>(
              // Only ranks the current user's friends (+ themselves), not
              // every app user. A prior version queried all users globally,
              // which exposed freely-editable display names to strangers
              // with no report/block mechanism (App Store Guideline 1.2).
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .snapshots(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: accent),
                  );
                }

                final userData = userSnap.data?.data() as Map<String, dynamic>?;
                final friends = (userData?['friends'] as List<dynamic>?) ?? [];

                var queryIds = <String>[
                  currentUserId,
                  ...friends.cast<String>(),
                ];
                // Firestore 'in' queries allow a maximum of 30 items
                if (queryIds.length > 30) queryIds = queryIds.sublist(0, 30);

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where(FieldPath.documentId, whereIn: queryIds)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: accent),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No explorers found in orbit yet.',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    }

                    // Rank by 'current_level' first, then 'global_xp' (XP
                    // progress within that level -- TelemetryProvider
                    // resets it to 0 on every level-up rather than
                    // accumulating it, so it's only meaningful as a
                    // same-level tiebreaker, not a standalone score). The
                    // old code ranked by 'xp', RoutineProvider's spendable
                    // currency (streak freezes, Nebula theme unlocks cost
                    // XP from it) -- so spending in the store actively
                    // lowered your leaderboard rank.
                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aLevel = (aData['current_level'] as num?)?.toInt() ?? 1;
                        final bLevel = (bData['current_level'] as num?)?.toInt() ?? 1;
                        if (aLevel != bLevel) return bLevel.compareTo(aLevel);
                        final aXp = (aData['global_xp'] as num?)?.toInt() ?? 0;
                        final bXp = (bData['global_xp'] as num?)?.toInt() ?? 0;
                        return bXp.compareTo(aXp);
                      });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final rank = index + 1;
                        final isMe = docs[index].id == currentUserId;

                        final name = data['name'] ?? 'Explorer';
                        final xp = (data['global_xp'] as num?)?.toInt() ?? 0;
                        final level = (data['current_level'] as num?)?.toInt() ?? 1;
                        final photoUrl = data['photoUrl'] as String?;

                        final rankColor = _getRankColor(rank);
                        final isTop3 = rank <= 3;

                        Widget card = PremiumGlassCard(
                          padding: const EdgeInsets.all(4),
                          child: ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    '#$rank',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: rank <= 3
                                          ? rankColor
                                          : textColor.withValues(alpha: 0.5),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: rankColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  backgroundImage: photoUrl != null
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl == null
                                      ? Icon(Icons.person, color: rankColor)
                                      : null,
                                ),
                              ],
                            ),
                            title: Text(
                              isMe ? '$name (You)' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isMe ? accent : textColor,
                                fontWeight: isMe
                                    ? FontWeight.w900
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Level $level',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                            trailing: Text(
                              '$xp XP',
                              style: TextStyle(
                                color: rankColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );

                        if (!isMe) {
                          card = GestureDetector(
                            onLongPress: () =>
                                _confirmRemoveFriend(docs[index].id, name.toString()),
                            child: card,
                          );
                        }

                        // Add a pulsing glow to the top 3 ranks!
                        if (isTop3) {
                          card = card
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .boxShadow(
                                begin: const BoxShadow(
                                  color: Colors.transparent,
                                ),
                                end: BoxShadow(
                                  color: rankColor.withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                                duration: 1.5.seconds,
                              );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: card
                              .animate()
                              .fade(delay: (index * 50).ms)
                              .slideX(begin: 0.1),
                        );
                      },
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
