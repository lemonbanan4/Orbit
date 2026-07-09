import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../common/add_friend_screen.dart';
import 'friends_leaderboard_tab.dart';
import '../common/friend_requests_screen.dart';
import '../../widgets/common/base_orbit_screen.dart';

// NOTE: The "Global" leaderboard tab (all app users, ranked by XP) is
// intentionally disabled for now. It displayed freely user-editable
// displayNames to strangers app-wide with no report/block/filter
// mechanism, which doesn't meet App Store Guideline 1.2's UGC
// moderation requirements. Re-enable only once reporting/blocking is
// in place; see global_leaderboard_tab.dart (kept, unused).
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final currentUser = FirebaseAuth.instance.currentUser;

    return BaseOrbitScreen(
      title: 'Friends Leaderboard',
      actions: [
        StreamBuilder<QuerySnapshot>(
          stream: currentUser != null
              ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('friend_requests')
                  .where('status', isEqualTo: 'pending')
                  .snapshots()
              : const Stream.empty(),
          builder: (context, snapshot) {
            final pendingCount = snapshot.data?.docs.length ?? 0;

            Widget badgeWidget = Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(
                pendingCount.toString(),
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF00E5FF),
              child: Icon(Icons.mark_email_unread_rounded, color: textColor),
            );

            if (pendingCount > 0) {
              badgeWidget = badgeWidget
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.15, duration: 600.ms);
            }

            return IconButton(
              icon: badgeWidget,
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FriendRequestsScreen()));
              },
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.person_add_alt_1_rounded, color: textColor),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddFriendScreen()));
          },
        ),
      ],
      body: const FriendsLeaderboardTab(),
    );
  }
}
