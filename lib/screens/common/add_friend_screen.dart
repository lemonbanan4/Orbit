import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/premium_glass_card.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _sentRequests =
      {}; // Tracks requests sent during this session

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final currentUser = FirebaseAuth.instance.currentUser;

    return BaseOrbitScreen(
      title: 'Add Friends',
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            PremiumGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by username...',
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  icon: Icon(Icons.search_rounded,
                      color: textColor.withValues(alpha: 0.5)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: textColor.withValues(alpha: 0.5)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _searchQuery.isEmpty
                  ? Center(
                      child: Text(
                        'Find fellow explorers to join your orbit.',
                        style:
                            TextStyle(color: textColor.withValues(alpha: 0.5)),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('displayName',
                              isGreaterThanOrEqualTo: _searchController.text)
                          .where('displayName',
                              isLessThanOrEqualTo:
                                  '${_searchController.text}\uf8ff')
                          .limit(20)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF00E5FF)));
                        }

                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Search failed.',
                                  style: TextStyle(color: textColor)));
                        }

                        final results = snapshot.data?.docs ?? [];
                        final filteredResults = results
                            .where((doc) => doc.id != currentUser?.uid)
                            .toList();

                        if (filteredResults.isEmpty) {
                          return Center(
                              child: Text('No users found.',
                                  style: TextStyle(color: textColor)));
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredResults.length,
                          itemBuilder: (context, index) {
                            final userData = filteredResults[index].data()
                                as Map<String, dynamic>;
                            final name = userData['displayName'] ?? 'Unknown';
                            final xp = userData['xp'] ?? 0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: PremiumGlassCard(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Colors.white10,
                                      child: Icon(Icons.person,
                                          color: Colors.white54),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '$xp XP',
                                            style: const TextStyle(
                                              color: Color(0xFF00E5FF),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(filteredResults[index].id)
                                          .collection('friend_requests')
                                          .doc(currentUser?.uid)
                                          .get(),
                                      builder: (context, reqSnapshot) {
                                        final targetUserId =
                                            filteredResults[index].id;
                                        final isSentBackend =
                                            reqSnapshot.data?.exists == true;
                                        final isSent = _sentRequests
                                                .contains(targetUserId) ||
                                            isSentBackend;

                                        return ElevatedButton(
                                          onPressed: isSent
                                              ? null
                                              : () async {
                                                  if (currentUser == null) {
                                                    return;
                                                  }
                                                  setState(() {
                                                    _sentRequests
                                                        .add(targetUserId);
                                                  });
                                                  try {
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('users')
                                                        .doc(targetUserId)
                                                        .collection(
                                                            'friend_requests')
                                                        .doc(currentUser.uid)
                                                        .set({
                                                      'senderId':
                                                          currentUser.uid,
                                                      'senderName': currentUser
                                                              .displayName ??
                                                          'Commander',
                                                      'status': 'pending',
                                                      'timestamp': FieldValue
                                                          .serverTimestamp(),
                                                    });
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              'Friend request sent to $name!'),
                                                          backgroundColor:
                                                              const Color(
                                                                  0xFF00E5FF),
                                                          behavior:
                                                              SnackBarBehavior
                                                                  .floating,
                                                        ),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    setState(() {
                                                      _sentRequests
                                                          .remove(targetUserId);
                                                    });
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                              'Failed to send request.'),
                                                          backgroundColor:
                                                              Colors.redAccent,
                                                          behavior:
                                                              SnackBarBehavior
                                                                  .floating,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isSent
                                                ? Colors.grey
                                                    .withValues(alpha: 0.3)
                                                : const Color(0xFF7000FF),
                                            foregroundColor: isSent
                                                ? Colors.white54
                                                : Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(isSent ? 'Sent' : 'Add'),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
