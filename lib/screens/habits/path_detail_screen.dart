// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;
import 'package:table_calendar/table_calendar.dart';
import '../../widgets/reward_popup.dart';

class PathDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const PathDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  State<PathDetailScreen> createState() => _PathDetailScreenState();
}

class _PathDetailScreenState extends State<PathDetailScreen> {
  late ConfettiController _confettiController;
  late ConfettiController _unthawController;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _unthawController = ConfettiController(
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _unthawController.dispose();
    super.dispose();
  }

  bool _isCompletedToday(Timestamp? lastCompleted) {
    if (lastCompleted == null) return false;
    final date = lastCompleted.toDate();
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _markComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isCompleting = true);

    final habitId = widget.title.toLowerCase().replaceAll(' ', '_');
    final habitRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('habits')
        .doc(habitId);
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    int xpEarned = 25;
    bool fullyCompleted = false;
    bool wasFrozen = false; // Initialize outside the try block
    int newTotalXp = 0;
    try {
      wasFrozen =
          await FirebaseFirestore.instance.runTransaction((transaction) async {
        final habitSnap = await transaction.get(habitRef);
        final userSnap = await transaction.get(userRef);

        int completed = 1;
        bool wasFrozen = false;
        int totalDays = 7;
        if (habitSnap.exists) {
          final data = habitSnap.data() as Map<String, dynamic>;
          completed = (data['completedDays'] as int? ?? 0) + 1;
          totalDays = data['totalDays'] as int? ?? 7;
        }

        final now = DateTime.now();
        final dateStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        // 1. Update the Habit Document
        transaction.set(
            habitRef,
            {
              'path': widget.title,
              'completedDays': completed,
              'totalDays': totalDays,
              'last_completed': FieldValue.serverTimestamp(),
              'completedDates': FieldValue.arrayUnion([dateStr]),
            },
            SetOptions(merge: true));

        // 2. Increment the User's Global Streak
        int newStreak = 1;
        if (userSnap.exists) {
          final userData = userSnap.data() as Map<String, dynamic>;
          final currentStreak = userData['streakCount'] as int? ?? 0;
          wasFrozen = userData['isStreakFrozen'] == true;
          final lastCompletedTs = userData['last_completed'] as Timestamp?;

          if (lastCompletedTs != null) {
            final lastCompleted = lastCompletedTs.toDate();
            final difference = DateTime.now().difference(lastCompleted).inHours;

            if (difference <= 48) {
              newStreak = currentStreak + 1;
            } else {
              newStreak = 1;
            }
          } else {
            newStreak = currentStreak + 1;
          }
        }

        fullyCompleted = completed >= totalDays;
        xpEarned = fullyCompleted ? 125 : 25;

        if (userSnap.exists) {
          final userData = userSnap.data() as Map<String, dynamic>;
          newTotalXp = (userData['xp'] as int? ?? 0) + xpEarned;
        } else {
          newTotalXp = xpEarned;
        }

        final Map<String, dynamic> userUpdates = {
          'streakCount': newStreak,
          'last_completed': FieldValue.serverTimestamp(),
          'xp': FieldValue.increment(
            xpEarned,
          ), // Big reward for finishing the path!
          'isStreakFrozen': false, // Unthaw the streak!
        };

        // Automatically archive the journey if it is fully complete!
        if (fullyCompleted) {
          userUpdates['interests'] = FieldValue.arrayRemove([widget.title]);
        }

        // Automatically grant achievements based on streak milestones!
        if (newStreak == 7) {
          userUpdates['achievements'] = FieldValue.arrayUnion(['7_Day_Streak']);
        } else if (newStreak == 10) {
          userUpdates['achievements'] = FieldValue.arrayUnion([
            '10_Day_Streak',
          ]);
        } else if (newStreak == 30) {
          userUpdates['achievements'] = FieldValue.arrayUnion([
            '30_Day_Streak',
          ]);
        } else if (newStreak == 100) {
          userUpdates['achievements'] = FieldValue.arrayUnion([
            '100_Day_Streak',
          ]);
        }

        transaction.update(userRef, userUpdates);

        return wasFrozen;
      });

      HapticFeedback.heavyImpact();
      if (mounted && context.read<RoutineProvider>().confettiEnabled) {
        if (wasFrozen) {
          _unthawController.play();
        } else {
          _confettiController.play();
        }
      }

      // Force the provider to refresh so global XP and the Cosmic Map update instantly!
      if (mounted) {
        context.read<RoutineProvider>().refreshData();
        RewardPopup.show(
          context,
          title:
              fullyCompleted ? "Journey Phase Complete!" : "Path Progressed!",
          xpEarned: xpEarned,
          currentTotalXp: newTotalXp,
          audioPath: fullyCompleted
              ? 'audio/milestone_unlock.mp3'
              : 'audio/success_chime.mp3',
        );
      }
    } catch (e) {
      debugPrint('Failed to mark complete: $e');
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .collection('habits')
                .doc(widget.title.toLowerCase().replaceAll(' ', '_'))
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final lastCompleted = data?['last_completed'] as Timestamp?;
              final isDoneToday = _isCompletedToday(lastCompleted);
              final completedDates =
                  (data?['completedDates'] as List<dynamic>?)?.cast<String>() ??
                      [];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(widget.icon, size: 80, color: const Color(0xFF1A1F36)),
                    const SizedBox(height: 24),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1F36),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isDoneToday
                          ? 'Awesome job checking in today! 🎉'
                          : 'Ready to crush this habit today?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: DateTime.now(),
                        calendarFormat: CalendarFormat.month,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        selectedDayPredicate: (day) {
                          final dateStr =
                              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                          return completedDates.contains(dateStr);
                        },
                        calendarStyle: const CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: Color(0xFF00E5FF),
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(
                            color: Color(0xFF1A1F36),
                            fontWeight: FontWeight.bold,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Color(0xFF00E5FF), width: 2),
                            ),
                          ),
                          todayTextStyle: TextStyle(color: Color(0xFF1A1F36)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDoneToday
                              ? Colors.green
                              : const Color(0xFF00E5FF),
                          foregroundColor: isDoneToday
                              ? Colors.white
                              : const Color(0xFF1A1F36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed:
                            isDoneToday || _isCompleting ? null : _markComplete,
                        icon: _isCompleting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF1A1F36),
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isDoneToday
                                    ? Icons.check_circle_rounded
                                    : Icons.local_fire_department_rounded,
                              ),
                        label: Text(
                          isDoneToday ? 'Completed Today' : 'Mark as Complete',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ).animate().scaleXY(
                          begin: 0.9,
                          end: 1.0,
                          curve: Curves.easeOutBack,
                        ),
                  ],
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.directional, // Downwards
              blastDirection: math.pi / 2,
              maxBlastForce: 25,
              minBlastForce: 10,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.2,
              colors: const [
                Color(0xFF00E5FF),
                Color(0xFF7000FF),
                Colors.white,
              ],
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _unthawController,
              blastDirectionality:
                  BlastDirectionality.explosive, // Burst from center
              maxBlastForce: 40,
              minBlastForce: 20,
              emissionFrequency: 0.1,
              numberOfParticles: 30,
              gravity: 0.1,
              colors: const [
                Colors.lightBlueAccent,
                Colors.cyanAccent,
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
