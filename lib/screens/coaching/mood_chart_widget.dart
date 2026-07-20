import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:orbit_app/widgets/common/premium_glass_card.dart';

class MoodChartWidget extends StatefulWidget {
  const MoodChartWidget({super.key});

  @override
  State<MoodChartWidget> createState() => _MoodChartWidgetState();
}

class _MoodChartWidgetState extends State<MoodChartWidget> {
  // Define colors for each mood to be used in the chart
  final Map<String, Color> _moodColors = {
    'Energized': Colors.orange,
    'Focused': Colors.cyan,
    'Calm': Colors.green,
    'Tired': Colors.blueGrey,
    'Stressed': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    // Query for coaching notes from the last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final notesStream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('coaching_notes')
        .where('createdAt', isGreaterThan: thirtyDaysAgo)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: notesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const PremiumGlassCard(
            child: Center(
              child: Text(
                'No mood data from the last 30 days.\nComplete a coaching session to see your analysis!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        // Process the data to count mood occurrences
        final moodCounts = <String, int>{};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          // statistics_screen.dart reads this same field defensively as
          // String? -- match that here instead of a non-nullable cast, so
          // a future writer that sets 'mood': null doesn't crash this
          // widget while leaving the other screen unaffected.
          final mood = data['mood'] as String?;
          if (mood != null) {
            moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
          }
        }

        if (moodCounts.isEmpty) {
          return const SizedBox.shrink(); // Don't show if no moods were logged
        }

        // Create chart sections from the processed data
        final totalCount = moodCounts.values.reduce((a, b) => a + b);
        final sections = moodCounts.entries.map((entry) {
          final percentage = (entry.value / totalCount) * 100;
          return PieChartSectionData(
            color: _moodColors[entry.key] ?? Colors.grey,
            value: entry.value.toDouble(),
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          );
        }).toList();

        return PremiumGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Mood Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Based on your coaching sessions from the last 30 days.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // The Pie Chart
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 150,
                      child: PieChart(
                        PieChartData(
                          sections: sections,
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 25,
                        ),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // The Legend
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: moodCounts.keys.map((mood) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _moodColors[mood],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                mood,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fade(duration: 500.ms).slideY(begin: 0.1);
      },
    );
  }
}
