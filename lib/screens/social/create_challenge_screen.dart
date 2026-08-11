import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/orbit_colors.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../../widgets/common/primary_button.dart';
import '../../services/challenge_service.dart';

/// Invite a subset of your existing mutual friends into a time-boxed
/// shared commitment (see ChallengeService.createChallenge). Reuses the
/// same friends-array + batched users query pattern as LeaderboardScreen
/// rather than a separate friend-search flow -- you can only challenge
/// people you're already friends with.
class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _titleController = TextEditingController();
  final _goalController = TextEditingController();
  int _durationDays = 7;
  final Set<String> _selectedFriendUids = {};
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your challenge a title.')),
      );
      return;
    }
    if (_selectedFriendUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite at least one friend.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final error = await ChallengeService.createChallenge(
      title: title,
      goal: _goalController.text.trim(),
      durationDays: _durationDays,
      inviteeUids: _selectedFriendUids.toList(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  Widget _durationChip(int days) {
    final selected = _durationDays == days;
    final accent =
        Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _durationDays = days);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accent : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            '$days days',
            style: TextStyle(
              color: selected ? accent : Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final accent =
        Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);

    return BaseOrbitScreen(
      title: 'New Challenge',
      body: currentUserId == null
          ? const Center(child: Text('Please log in.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PremiumGlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. No Sugar Week',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _goalController,
                      maxLines: 2,
                      maxLength: 300,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'What\'s the goal? (optional)',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        counterStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'DURATION',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _durationChip(7),
                        _durationChip(14),
                        _durationChip(30),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'INVITE FRIENDS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUserId)
                          .snapshots(),
                      builder: (context, userSnap) {
                        final userData =
                            userSnap.data?.data() as Map<String, dynamic>?;
                        final friendUids = ((userData?['friends'] as List?) ?? [])
                            .cast<String>();
                        if (userSnap.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(color: accent),
                          );
                        }
                        if (friendUids.isEmpty) {
                          return Text(
                            'Add some friends first to challenge them.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          );
                        }
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .where(
                                FieldPath.documentId,
                                whereIn: friendUids.length > 30
                                    ? friendUids.sublist(0, 30)
                                    : friendUids,
                              )
                              .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: accent,
                                ),
                              );
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: snap.data!.docs.map((doc) {
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                final name =
                                    data['name']?.toString() ?? 'Explorer';
                                final selected = _selectedFriendUids.contains(
                                  doc.id,
                                );
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      if (selected) {
                                        _selectedFriendUids.remove(doc.id);
                                      } else {
                                        _selectedFriendUids.add(doc.id);
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                      milliseconds: 180,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? accent.withValues(alpha: 0.15)
                                          : Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: selected
                                            ? accent
                                            : Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                      ),
                                    ),
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.white54,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: 'CREATE CHALLENGE',
                      isLoading: _isSaving,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _create();
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
