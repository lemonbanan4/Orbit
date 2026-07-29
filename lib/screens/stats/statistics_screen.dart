import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/routine_provider.dart';
import '../../models/habit.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/user_metrics_grid.dart';
import '../../widgets/mission_progress_card.dart';
import '../../theme/orbit_colors.dart'; // For accessing our custom theme colors
import '../coaching/mood_chart_widget.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final routineProvider = context.watch<RoutineProvider>();

    final Color orbColor1 =
        Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);

    return BaseOrbitScreen(
      title: 'Your Stats',
      body: user == null
          ? Center(child: CircularProgressIndicator(color: orbColor1))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
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
                    // --- MISSION PROGRESS (dashboard hero) ---
                    const MissionProgressCard(),
                    const SizedBox(height: 40),
                    // --- TOP METRICS ---
                    UserMetricsGrid(
                      currentStreak: currentStreak,
                      longestStreak: longestStreak,
                      completedMilestones: completedMilestones,
                      // routineProvider.xp is spendable currency (streak
                      // freezes, Nebula theme unlocks spend it) -- it
                      // *decreases*, so "Total XP Earned" showed a number
                      // that could go down. xpHistory is a live per-day
                      // ledger of every +10 actually earned (see
                      // incrementTotalHabits), so summing it is the real
                      // lifetime total, same pool the XP History graph
                      // below already reads from.
                      totalXp: routineProvider.xpHistory.values.fold(
                        0,
                        (total, xp) => total + xp,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const _HabitInsightsCard(),
                    const SizedBox(height: 40),
                    const _HabitHeatmapCard(),
                    const SizedBox(height: 40),
                    const _ConsistencyCalendar(),
                    const SizedBox(height: 40),
                    const _WeeklyConsistencyChart(),
                    const SizedBox(height: 40),
                    const _BestDayCard(),
                    const SizedBox(height: 40),
                    const _XpHistoryGraph(),
                    const SizedBox(height: 40),
                    const _PastMoodEntries(),
                    const SizedBox(height: 40),
                    const MoodChartWidget(),
                    const SizedBox(height: 40),
                    const _PastCoachingNotes(),
                    const SizedBox(height: 40),
                    const _PastIntentions(),
                  ],
                );
              },
            ),
    );
  }
}

class _ConsistencyCalendar extends StatefulWidget {
  const _ConsistencyCalendar();

  @override
  State<_ConsistencyCalendar> createState() => _ConsistencyCalendarState();
}

class _ConsistencyCalendarState extends State<_ConsistencyCalendar> {
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final routineProvider = context.watch<RoutineProvider>();
    final orbitColors = theme.extension<OrbitColors>();
    final Color orbColor1 = orbitColors?.orbColor1 ?? const Color(0xFF00E5FF);
    final Color orbColor2 = orbitColors?.orbColor2 ?? const Color(0xFF7000FF);

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
            // Tapping a day used to do nothing at all -- every day's real
            // completion/mood/intention data was already being collected
            // and shown separately elsewhere on this screen, just never
            // surfaced together for a specific date.
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              HapticFeedback.selectionClick();
              setState(() => _selectedDay = selectedDay);
              _showDayDetail(context, selectedDay, routineProvider);
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleTextStyle: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
              rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: textColor.withValues(alpha: 0.6)),
              weekendStyle: TextStyle(color: textColor.withValues(alpha: 0.6)),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: textColor),
              weekendTextStyle: TextStyle(color: textColor),
              outsideTextStyle: TextStyle(
                color: textColor.withValues(alpha: 0.3),
              ),
              todayDecoration: BoxDecoration(
                color: orbColor2.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: orbColor1,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: orbColor1,
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

  void _showDayDetail(
    BuildContext context,
    DateTime day,
    RoutineProvider routineProvider,
  ) {
    final dateStr = day.toIso8601String().substring(0, 10);
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final orbColor1 =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);

    final xp = routineProvider.xpHistory[dateStr] ?? 0;
    final mood = routineProvider.moodHistory[dateStr];
    final intention = routineProvider.intentionHistory[dateStr];
    // habit.history only has an entry once a habit has actually been
    // through a daily-reset rollover for that date -- a habit created
    // after this date, or a day with no rollover yet (e.g. today, still
    // in progress) legitimately has nothing to show here.
    final habitEntries =
        routineProvider.habits.values
            .where((h) => h.history.containsKey(dateStr))
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    final isToday = isSameDay(day, DateTime.now());
    final hasAnyData =
        xp > 0 || mood != null || intention != null || habitEntries.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            color: const Color(0xFF13182B),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  '${_monthName(day.month)} ${day.day}, ${day.year}'
                  '${isToday ? " · Today" : ""}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                if (!hasAnyData)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      isToday
                          ? "Today's story is still being written."
                          : 'No data logged for this day.',
                      style: TextStyle(color: textColor.withValues(alpha: 0.5)),
                    ),
                  ),
                if (xp > 0) ...[
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: orbColor1, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '+$xp XP earned',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (intention != null) ...[
                  Text(
                    'INTENTION',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"$intention"',
                    style: TextStyle(
                      color: textColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (mood != null) ...[
                  Text(
                    'MOOD',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mood['mood'] ?? '',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((mood['note'] ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        mood['note']!,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                if (habitEntries.isNotEmpty) ...[
                  Text(
                    'HABITS',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...habitEntries.map((habit) {
                    final done = habit.history[dateStr] == true;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 18,
                            color: done ? orbColor1 : Colors.white24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              habit.title,
                              style: TextStyle(
                                color: done
                                    ? textColor
                                    : textColor.withValues(alpha: 0.5),
                                decoration: done
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }
}

class _HabitInsightsCard extends StatelessWidget {
  const _HabitInsightsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final Color orbColor1 =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);
    final routineProvider = context.watch<RoutineProvider>();

    // Only habits that have survived at least one daily reset carry a real
    // completion rate — brand-new habits (totalDays == 0) would show as a
    // false 0% or divide-by-zero.
    final tracked =
        routineProvider.habits.values.where((h) => h.totalDays > 0).toList()
          ..sort(
            (a, b) => (b.completedDays / b.totalDays).compareTo(
              a.completedDays / a.totalDays,
            ),
          );

    if (tracked.isEmpty) {
      return const SizedBox.shrink();
    }

    final strongest = tracked.take(3).toList();
    // Only call out a struggling habit once it's had a fair number of
    // chances — otherwise one skipped day on day one reads as a failure.
    final weakestCandidate = tracked.length > 3 ? tracked.last : null;
    final weakest =
        (weakestCandidate != null && weakestCandidate.totalDays >= 3)
        ? weakestCandidate
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Habit Insights',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        PremiumGlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < strongest.length; i++) ...[
                if (i > 0)
                  Divider(color: textColor.withValues(alpha: 0.08), height: 1),
                _HabitInsightRow(
                  habit: strongest[i],
                  badge: i == 0 ? '🏆' : (i == 1 ? '🥈' : '🥉'),
                  accent: orbColor1,
                ),
              ],
              if (weakest != null) ...[
                Divider(color: textColor.withValues(alpha: 0.08), height: 1),
                _HabitInsightRow(
                  habit: weakest,
                  badge: '⚠️',
                  accent: Colors.orangeAccent,
                  label: 'Needs attention',
                ),
              ],
            ],
          ),
        ).animate().fade(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1),
      ],
    );
  }
}

class _HabitInsightRow extends StatelessWidget {
  final Habit habit;
  final String badge;
  final Color accent;
  final String? label;

  const _HabitInsightRow({
    required this.habit,
    required this.badge,
    required this.accent,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final rate = (habit.completedDays / habit.totalDays).clamp(0.0, 1.0);
    final pct = (rate * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: Row(
        children: [
          Text(badge, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (label != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    label!,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 4,
                    backgroundColor: textColor.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '$pct%',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitHeatmapCard extends StatefulWidget {
  const _HabitHeatmapCard();

  @override
  State<_HabitHeatmapCard> createState() => _HabitHeatmapCardState();
}

class _HabitHeatmapCardState extends State<_HabitHeatmapCard> {
  String? _selectedHabitId;

  static const int _weeksShown = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final Color orbColor1 =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);
    final routineProvider = context.watch<RoutineProvider>();

    final habits = routineProvider.habits.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    if (habits.isEmpty) {
      return const SizedBox.shrink();
    }

    final selected = habits.firstWhere(
      (h) => h.id == _selectedHabitId,
      orElse: () => habits.first,
    );

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    // Anchor the grid to the end of the current week (Sunday-start) so it
    // always renders full 7-day columns; days past today are masked out.
    final daysSinceSunday = todayMidnight.weekday % 7;
    final gridEnd = todayMidnight.add(Duration(days: 6 - daysSinceSunday));
    final gridStart = gridEnd.subtract(
      const Duration(days: _weeksShown * 7 - 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Habit History',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        PremiumGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: habits.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final h = habits[i];
                    final isSelected = h.id == selected.id;
                    return ChoiceChip(
                      label: Text(h.title),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedHabitId = h.id),
                      selectedColor: orbColor1.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? orbColor1
                            : textColor.withValues(alpha: 0.7),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      backgroundColor: textColor.withValues(alpha: 0.05),
                      side: BorderSide(
                        color: isSelected
                            ? orbColor1
                            : textColor.withValues(alpha: 0.15),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: List.generate(_weeksShown, (week) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(7, (dayOfWeek) {
                          final date = gridStart.add(
                            Duration(days: week * 7 + dayOfWeek),
                          );
                          final isFuture = date.isAfter(todayMidnight);
                          final dateKey = date.toIso8601String().substring(
                            0,
                            10,
                          );
                          final status = selected.history[dateKey];

                          Color cellColor;
                          if (isFuture) {
                            cellColor = Colors.transparent;
                          } else if (status == true) {
                            cellColor = orbColor1;
                          } else if (status == false) {
                            cellColor = textColor.withValues(alpha: 0.14);
                          } else {
                            cellColor = textColor.withValues(alpha: 0.05);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: cellColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Less',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: orbColor1,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'More',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fade(delay: 160.ms, duration: 400.ms).slideY(begin: 0.1),
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
    final Color orbColor1 = orbitColors?.orbColor1 ?? const Color(0xFF00E5FF);
    final Color orbColor2 = orbitColors?.orbColor2 ?? const Color(0xFF7000FF);

    // Matches the rest of this screen's convention (_HabitInsightsCard,
    // _HabitHeatmapCard, _BestDayCard) of hiding a card entirely rather
    // than rendering a chart with nothing meaningful to plot -- a
    // brand-new user with zero habits used to see a flat, unexplained
    // empty line here.
    if (routineProvider.habits.isEmpty) {
      return const SizedBox.shrink();
    }

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
                          Duration(days: 6 - value.toInt()),
                        );
                        const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
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
                    // weeklyProgress only advances during the daily-reset
                    // rollover (it stores *yesterday's* completion rate),
                    // so its last entry is always yesterday -- yet the
                    // x-axis below explicitly labels index 6 "today". Shift
                    // the window to end on today's live completion rate
                    // (the 6 stored entries already cover the 6 days before
                    // that) so the label and the plotted value agree.
                    spots: List.generate(7, (index) {
                      if (index == 6) {
                        // Match weeklyProgress's methodology (routine_
                        // provider.dart) -- it only counts habits actually
                        // due that day, or completed anyway. Unfiltered
                        // would make today's point dip relative to the
                        // rest of the line whenever a non-daily habit
                        // isn't scheduled.
                        final todayHabits = routineProvider.habits.values
                            .where(
                              (h) =>
                                  h.isCompleted ||
                                  (!h.isArchived && h.isActiveOn()),
                            )
                            .toList();
                        final todayProgress = todayHabits.isEmpty
                            ? 0.0
                            : todayHabits.where((h) => h.isCompleted).length /
                                  todayHabits.length;
                        return FlSpot(6, todayProgress);
                      }
                      return FlSpot(
                        index.toDouble(),
                        routineProvider.weeklyProgress[index + 1],
                      );
                    }),
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
                            TextStyle(
                              color: orbColor1,
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
    final Color orbColor1 =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);

    // Same reasoning as _WeeklyConsistencyChart above -- a user who's
    // never earned any XP used to see a row of zero-height bars with no
    // explanation instead of this card just not appearing.
    if (routineProvider.xpHistory.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  final date = now.subtract(Duration(days: i));
                  final dateStr = date.toIso8601String().substring(0, 10);
                  final xp = (routineProvider.xpHistory[dateStr] ?? 0)
                      .toDouble();
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
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final formattedXp = rod.toY
                              .toInt()
                              .toString()
                              .replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',');

                          return BarTooltipItem(
                            '$formattedXp XP\n',
                            TextStyle(
                              color: orbColor1,
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
                              Duration(days: 6 - value.toInt()),
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
                      final date = now.subtract(Duration(days: 6 - index));
                      final dateStr = date.toIso8601String().substring(0, 10);
                      final xp = (routineProvider.xpHistory[dateStr] ?? 0)
                          .toDouble();

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
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                );
              },
            ),
          ),
        ).animate().fade(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
      ],
    );
  }
}

class _BestDayCard extends StatelessWidget {
  const _BestDayCard();

  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<String> _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final Color orbColor1 =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);
    final routineProvider = context.watch<RoutineProvider>();

    // Average XP earned per weekday, computed from real date-keyed
    // history — not a rolling window, so this reflects the user's whole
    // tracked lifetime rather than just the last 7 days.
    final totals = List<int>.filled(7, 0);
    final daysSeen = List<int>.filled(7, 0);
    routineProvider.xpHistory.forEach((dateStr, xp) {
      final date = DateTime.tryParse(dateStr);
      if (date == null) return;
      final idx = date.weekday - 1;
      totals[idx] += xp;
      daysSeen[idx]++;
    });

    // Need a handful of different weekdays represented before calling out
    // a "best" one — otherwise one lucky Tuesday looks like a pattern.
    final weekdaysWithData = daysSeen.where((c) => c > 0).length;
    if (weekdaysWithData < 3) {
      return const SizedBox.shrink();
    }

    final averages = List<double>.generate(
      7,
      (i) => daysSeen[i] == 0 ? 0.0 : totals[i] / daysSeen[i],
    );
    var bestIdx = 0;
    for (var i = 1; i < 7; i++) {
      if (averages[i] > averages[bestIdx]) bestIdx = i;
    }
    final maxAvg = averages.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Best Day',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        PremiumGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: orbColor1, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "You're most consistent on ${_weekdayNames[bestIdx]}s",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxAvg <= 0 ? 1 : maxAvg * 1.2,
                    barTouchData: const BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            final isBest = idx == bestIdx;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _weekdayShort[idx],
                                style: TextStyle(
                                  color: isBest
                                      ? orbColor1
                                      : textColor.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: isBest
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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
                      final isBest = index == bestIdx;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: averages[index],
                            color: isBest
                                ? orbColor1
                                : orbColor1.withValues(alpha: 0.3),
                            width: 16,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      );
                    }),
                  ),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                ),
              ),
            ],
          ),
        ).animate().fade(delay: 190.ms, duration: 400.ms).slideY(begin: 0.1),
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
                              context.read<RoutineProvider>().deleteMoodEntry(
                                dateStr,
                              );
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
    final Color orbColor1 =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);

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
                            child: Icon(
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

class _PastCoachingNotes extends StatelessWidget {
  const _PastCoachingNotes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final Color orbColor1 =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Past Reflections',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('coaching_notes')
              .orderBy('createdAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: orbColor1));
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Text(
                'No coaching reflections yet — complete a coaching session to see them here.',
                style: TextStyle(color: textColor.withValues(alpha: 0.54)),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final text = data['text'] as String? ?? '';
                final mood = data['mood'] as String?;
                final createdAt = data['createdAt'] as Timestamp?;
                final dateStr = createdAt != null
                    ? '${createdAt.toDate().year}-${createdAt.toDate().month.toString().padLeft(2, '0')}-${createdAt.toDate().day.toString().padLeft(2, '0')}'
                    : '';

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
                          child: Icon(
                            Icons.self_improvement_rounded,
                            color: orbColor1,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.54),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (mood != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '· $mood',
                                      style: TextStyle(
                                        color: orbColor1,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '"$text"',
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
                          // Was a single unconfirmed, fire-and-forget tap
                          // that permanently deleted a reflection with no
                          // confirm dialog (every other delete in the app
                          // has one) and no error feedback -- an offline/
                          // permission failure became a silent unhandled
                          // rejection. Now confirmed, awaited, and reported.
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Delete reflection?'),
                                content: const Text('This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            try {
                              await doc.reference.delete();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not delete. Please try again.',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
