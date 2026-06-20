import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/routine_provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/user_metrics_grid.dart';
import '../../theme/orbit_colors.dart'; // For accessing our custom theme colors

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final routineProvider = context.watch<RoutineProvider>();

    // These colors are part of the app's branding for charts.
    // Consider moving them to a theme extension for better reusability.
    const Color orbColor1 = Color(0xFF00E5FF); // Cyan accent
    const Color orbColor2 = Color(0xFF7000FF); // Purple accent

    return BaseOrbitScreen(
      title: 'Your Stats',
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(color: orbColor1),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: orbColor1),
                  );
                }

                final data =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final currentStreak = data['current_streak'] as int? ?? 0;
                final longestStreak =
                    data['longest_streak'] as int? ?? currentStreak;
                final completedMilestones =
                    (data['unlocked_milestones'] as List<dynamic>?)?.length ??
                        0;

                return ListView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // --- TOP METRICS ---
                    UserMetricsGrid(
                      currentStreak: currentStreak,
                      longestStreak: longestStreak,
                      completedMilestones: completedMilestones,
                      totalXp: routineProvider.xp,
                    ),
                    const SizedBox(height: 40),
                    const _ConsistencyCalendar(),
                    const SizedBox(height: 40),
                    const _WeeklyConsistencyChart(),
                    const SizedBox(height: 40),
                    const _XpHistoryGraph(),
                    const SizedBox(height: 40),
                    const _PastMoodEntries(),
                    const SizedBox(height: 40),
                    const _PastIntentions(),
                  ],
                );
              },
            ),
    );
  }
}

class _ConsistencyCalendar extends StatelessWidget {
  const _ConsistencyCalendar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final routineProvider = context.watch<RoutineProvider>();
    const Color orbColor2 = Color(0xFF7000FF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Consistency Calendar',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        PremiumGlassCard(
          padding: const EdgeInsets.all(8),
          child: TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: DateTime.now(),
            calendarFormat: CalendarFormat.month,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleTextStyle: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: textColor,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: textColor,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: textColor.withValues(alpha: 0.6),
              ),
              weekendStyle: TextStyle(
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(
                color: textColor,
              ),
              weekendTextStyle: TextStyle(
                color: textColor,
              ),
              outsideTextStyle: TextStyle(
                color: textColor.withValues(alpha: 0.3),
              ),
              todayDecoration: BoxDecoration(
                color: orbColor2.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFF00E5FF),
                shape: BoxShape.circle,
              ),
            ),
            eventLoader: (day) {
              final dateStr = day.toIso8601String().substring(0, 10);
              final xp = routineProvider.xpHistory[dateStr] ?? 0;
              return xp > 0 ? ['completed'] : [];
            },
          ),
        ).animate().fade(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1),
      ],
    );
  }
}

class _WeeklyConsistencyChart extends StatelessWidget {
  const _WeeklyConsistencyChart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final routineProvider = context.watch<RoutineProvider>();

    // Extract custom colors from the theme safely!
    final orbitColors = theme.extension<OrbitColors>();
    final Color orbColor2 = orbitColors?.orbColor2 ?? const Color(0xFF7000FF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Weekly Consistency',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        PremiumGlassCard(
          child: SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final date = DateTime.now().subtract(
                          Duration(
                            days: 6 - value.toInt(),
                          ),
                        );
                        const weekdays = [
                          'M',
                          'T',
                          'W',
                          'T',
                          'F',
                          'S',
                          'S',
                        ];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            weekdays[date.weekday - 1],
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      7,
                      (index) => FlSpot(
                        index.toDouble(),
                        routineProvider.weeklyProgress[index],
                      ),
                    ),
                    isCurved: true,
                    color: orbColor2,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: orbColor2.withValues(alpha: 0.2),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) =>
                        theme.dialogTheme.backgroundColor ?? theme.cardColor,
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map(
                          (spot) => LineTooltipItem(
                            '${(spot.y * 100).toInt()}%\n',
                            const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ).animate().fade(delay: 175.ms, duration: 400.ms).slideY(begin: 0.1),
      ],
    );
  }
}

class _XpHistoryGraph extends StatelessWidget {
  const _XpHistoryGraph();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final routineProvider = context.watch<RoutineProvider>();
    const Color orbColor1 = Color(0xFF00E5FF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'XP History Graph',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        PremiumGlassCard(
          child: SizedBox(
            height: 220,
            child: Builder(
              builder: (context) {
                final now = DateTime.now();
                double maxY = 100;

                for (int i = 0; i < 7; i++) {
                  final date = now.subtract(
                    Duration(days: i),
                  );
                  final dateStr = date.toIso8601String().substring(0, 10);
                  final xp =
                      (routineProvider.xpHistory[dateStr] ?? 0).toDouble();
                  if (xp > maxY) maxY = xp + 50;
                }

                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) =>
                            theme.dialogTheme.backgroundColor ??
                            theme.cardColor,
                        getTooltipItem: (
                          group,
                          groupIndex,
                          rod,
                          rodIndex,
                        ) {
                          final formattedXp =
                              rod.toY.toInt().toString().replaceAll(
                                    RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                    ',',
                                  );

                          return BarTooltipItem(
                            '$formattedXp XP\n',
                            const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final date = now.subtract(
                              Duration(
                                days: 6 - value.toInt(),
                              ),
                            );
                            const weekdays = [
                              'M',
                              'T',
                              'W',
                              'T',
                              'F',
                              'S',
                              'S',
                            ];
                            final label = weekdays[date.weekday - 1];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.54),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (index) {
                      final date = now.subtract(
                        Duration(days: 6 - index),
                      );
                      final dateStr = date.toIso8601String().substring(0, 10);
                      final xp =
                          (routineProvider.xpHistory[dateStr] ?? 0).toDouble();

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: xp,
                            color: orbColor1,
                            width: 16,
                            borderRadius: BorderRadius.circular(6),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY,
                              color: textColor.withValues(alpha: 0.05),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 800),
                  swapAnimationCurve: Curves.easeOutBack,
                );
              },
            ),
          ),
        ).animate().fade(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
      ],
    );
  }
}

class _PastMoodEntries extends StatelessWidget {
  const _PastMoodEntries();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final routineProvider = context.watch<RoutineProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Past Mood Entries',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (routineProvider.moodHistory.isEmpty)
          Text(
            'No mood entries logged yet.',
            style: TextStyle(color: textColor.withValues(alpha: 0.54)),
          )
        else
          Builder(
            builder: (context) {
              final sortedDates = routineProvider.moodHistory.keys.toList()
                ..sort((a, b) => b.compareTo(a));
              return Column(
                children: sortedDates.map((dateStr) {
                  final entry = routineProvider.moodHistory[dateStr]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: PremiumGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            entry['mood'] ?? '🙂',
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.54),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry['note']?.isNotEmpty == true
                                      ? entry['note']!
                                      : 'No note provided.',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              context
                                  .read<RoutineProvider>()
                                  .deleteMoodEntry(dateStr);
                            },
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.1);
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

class _PastIntentions extends StatelessWidget {
  const _PastIntentions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final routineProvider = context.watch<RoutineProvider>();
    const Color orbColor1 = Color(0xFF00E5FF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Past Daily Intentions',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (routineProvider.intentionHistory.isEmpty)
          Text(
            'No intentions set yet.',
            style: TextStyle(color: textColor.withValues(alpha: 0.54)),
          )
        else
          Builder(
            builder: (context) {
              final sortedDates = routineProvider.intentionHistory.keys.toList()
                ..sort((a, b) => b.compareTo(a));
              return Column(
                children: sortedDates.map((dateStr) {
                  final intention = routineProvider.intentionHistory[dateStr]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: PremiumGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: orbColor1.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flare_rounded,
                              color: orbColor1,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.54),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '"$intention"',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              context
                                  .read<RoutineProvider>()
                                  .deleteIntentionEntry(dateStr);
                            },
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.1);
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

class WeeklyProgressChart extends StatelessWidget {
  const WeeklyProgressChart({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<RoutineProvider>().weeklyProgress;

    // Convert data array to graph coordinates
    final spots = List.generate(
      progress.length,
      (index) => FlSpot(index.toDouble(), progress[index] * 100),
    );

    return PremiumGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consistency Rate',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false), // Hide borders
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1F36),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots
                          .map((spot) => LineTooltipItem(
                                '${spot.y.toInt()}%',
                                const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontWeight: FontWeight.bold),
                              ))
                          .toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF00E5FF),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF00E5FF),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00E5FF).withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
