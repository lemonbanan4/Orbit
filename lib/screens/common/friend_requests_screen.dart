import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/premium_glass_card.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return BaseOrbitScreen(
        title: 'Friend Requests',
        body: Center(
            child: Text("Please log in.", style: TextStyle(color: textColor))),
      );
    }

    return BaseOrbitScreen(
      title: 'Friend Requests',
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('friend_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }

          if (snapshot.hasError) {
            return Center(
                child: Text("Error loading requests.",
                    style: TextStyle(color: textColor)));
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return Center(
                child: Text("No pending requests.",
                    style: TextStyle(color: textColor.withValues(alpha: 0.5))));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final data = req.data() as Map<String, dynamic>;
              final senderName = data['senderName'] ?? 'Unknown';
              final senderId = data['senderId'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: PremiumGlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white10,
                        child: Icon(Icons.person, color: Colors.white54),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          senderName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded,
                            color: Colors.greenAccent),
                        onPressed: () async {
                          final batch = FirebaseFirestore.instance.batch();

                          // Clean up the pending request
                          batch.delete(req.reference);

                          // Add them to my friends list
                          batch.update(
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUser.uid),
                              {
                                'friends': FieldValue.arrayUnion([senderId])
                              });

                          // Add me to their friends list
                          batch.update(
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(senderId),
                              {
                                'friends':
                                    FieldValue.arrayUnion([currentUser.uid])
                              });

                          await batch.commit();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded,
                            color: Colors.redAccent),
                        onPressed: () async => await req.reference.delete(),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fade(delay: (index * 50).ms, duration: 400.ms)
                  .slideY(begin: 0.1);
            },
          );
        },
      ),
    );
  }
}
