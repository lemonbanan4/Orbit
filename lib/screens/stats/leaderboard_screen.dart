import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../common/add_friend_screen.dart';
import 'global_leaderboard_tab.dart';
import 'friends_leaderboard_tab.dart';
import '../common/friend_requests_screen.dart';
import '../../widgets/common/base_orbit_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final currentUser = FirebaseAuth.instance.currentUser;

    return BaseOrbitScreen(
      title: 'Leaderboard',
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
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: textColor,
        labelColor: textColor,
        unselectedLabelColor: textColor.withValues(alpha: 0.6),
        tabs: const [
          Tab(text: 'Global'),
          Tab(text: 'Friends'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          GlobalLeaderboardTab(),
          FriendsLeaderboardTab(),
        ],
      ),
    );
  }
}
