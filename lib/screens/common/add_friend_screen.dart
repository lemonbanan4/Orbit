import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/orbit_colors.dart';
import '../../theme/orbit_tokens.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  Timer? _debounce;
  Future<List<Map<String, dynamic>>>? _searchFuture;

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('searchUsers')
        .call({'query': query});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['results'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _searchFuture = value.trim().isEmpty ? null : _searchUsers(value.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final accent =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);
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
                onChanged: _onSearchChanged,
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
                            _debounce?.cancel();
                            setState(() {
                              _searchQuery = '';
                              _searchFuture = null;
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
                  : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _searchFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                              child: CircularProgressIndicator(
                                  color: accent));
                        }

                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Search failed.',
                                  style: TextStyle(color: textColor)));
                        }

                        final filteredResults = snapshot.data ?? [];

                        if (filteredResults.isEmpty) {
                          return Center(
                              child: Text('No users found.',
                                  style: TextStyle(color: textColor)));
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredResults.length,
                          itemBuilder: (context, index) {
                            final userData = filteredResults[index];
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
                                            style: TextStyle(
                                              color: accent,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Builder(
                                      builder: (context) {
                                        // Reading whether a request was
                                        // already sent would mean reading
                                        // the target's own friend_requests
                                        // subcollection, which
                                        // firestore.rules only lets the
                                        // target (not the sender) read —
                                        // so this can only track state for
                                        // the current session.
                                        final targetUserId =
                                            filteredResults[index]['uid']
                                                as String;
                                        final isSent =
                                            _sentRequests.contains(targetUserId);

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
                                                    // currentUser.displayName
                                                    // is the FirebaseAuth
                                                    // field, which is a
                                                    // separate, usually-null
                                                    // mirror of 'name' (the
                                                    // field actually shown/
                                                    // edited in the app) --
                                                    // read the real one so
                                                    // the recipient doesn't
                                                    // just see "Commander".
                                                    final selfDoc =
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'users')
                                                            .doc(currentUser
                                                                .uid)
                                                            .get();
                                                    final senderName =
                                                        selfDoc.data()?[
                                                                'name'] ??
                                                            currentUser
                                                                .displayName ??
                                                            'Commander';
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
                                                      'senderName':
                                                          senderName,
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
                                                              accent,
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
                                                : OrbitTokens.violet,
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
