import 'package:flutter/material.dart';
import 'profile_screen.dart';
import '../social/leaderboard_screen.dart';
import '../habit_dashboard_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import '../coaching/constellation_builder_screen.dart';
// import '../../services/ai_coach_service.dart';
import '../journey/journey_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/account_link_prompt_sheet.dart';

class MainNavigationScreen extends StatefulWidget {
  final String? highlightHabit;
  final String? initialTab;

  const MainNavigationScreen({super.key, this.highlightHabit, this.initialTab});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Screens are created once in initState and never rebuilt.
  //
  // IMPORTANT: Do NOT move this list into build(). Creating new widget
  // instances inside build() means AnimatedSwitcher / IndexedStack sees
  // a "new" child on every RoutineProvider.notifyListeners() call, which:
  //   1. Throws away existing screen state (kills the HabitDashboard state)
  //   2. During AnimatedSwitcher fade-out, HabitDashboardScreen is still
  //      mounted, so its build() fires again, queuing addPostFrameCallback
  //      that calls setState while ConstellationBuilderScreen is mid-layout
  //      → "dirty widget built in wrong build scope" assertion (line 6417).
  //
  // IndexedStack keeps all screens mounted so state persists across tabs.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      HabitDashboardScreen(highlightHabit: widget.highlightHabit),
      const JourneyScreen(),
      const ConstellationBuilderScreen(),
      const LeaderboardScreen(),
      const ProfileScreen(),
    ];

    // Trigger the link check asynchronously when the screen loads
    _checkGuestLinkPrompt();

    // Handle initial tab routing from deep links or notifications
    if (widget.initialTab != null) {
      switch (widget.initialTab) {
        case 'journey':
          _currentIndex = 1;
          break;
        case 'cosmos':
          _currentIndex = 2;
          break;
        case 'ranks':
          _currentIndex = 3;
          break;
        case 'profile':
          _currentIndex = 4;
          break;
        default:
          _currentIndex = 0; // 'habits' or unknown defaults to Home
      }
    }

    if (widget.highlightHabit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deep linked to habit: ${widget.highlightHabit}'),
          ),
        );
      });
    }
  }

  void _checkGuestLinkPrompt() async {
    final user = FirebaseAuth.instance.currentUser;

    // Only proceed if the user is a guest
    if (user != null && user.isAnonymous) {
      final prefs = await SharedPreferences.getInstance();

      // Don't spam them! Check if we've already shown the prompt.
      final hasSeenPrompt = prefs.getBool('has_seen_link_prompt') ?? false;
      if (hasSeenPrompt) return;

      final creationTime = user.metadata.creationTime;
      if (creationTime != null) {
        final daysUsingApp = DateTime.now().difference(creationTime).inDays;

        // If they've been using the app for 3 days or more, prompt them!
        if (daysUsingApp >= 3) {
          await prefs.setBool('has_seen_link_prompt', true);

          if (mounted) {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => const AccountLinkPromptSheet(),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use select so the nav shell only rebuilds when themeMode changes, not
    // on every habit completion / audio event. The screens inside IndexedStack
    // are late-final and watch the provider themselves for data they need.
    final isDark = context.select<RoutineProvider, bool>(
      (p) => p.themeMode == 'Dark' || p.themeMode == 'System',
    );
    final bgColor = isDark ? const Color(0xFF050112) : const Color(0xFFF0F4FF);
    final navBgColor = isDark ? const Color(0xFF0A102A) : Colors.white;
    final unselectedColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  )
                : TextStyle(color: unselectedColor, fontSize: 12),
          ),
        ),
        child: NavigationBar(
          backgroundColor: navBgColor,
          indicatorColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_rounded, color: unselectedColor),
              selectedIcon: const Icon(
                Icons.home_rounded,
                color: Color(0xFF00E5FF),
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.track_changes_rounded, color: unselectedColor),
              selectedIcon: const Icon(
                Icons.track_changes_rounded,
                color: Color(0xFF00E5FF),
              ),
              label: 'Journey',
            ),
            NavigationDestination(
              icon: Icon(Icons.mood_rounded, color: unselectedColor),
              selectedIcon: const Icon(
                Icons.mood_rounded,
                color: Color(0xFF00E5FF),
              ),
              label: 'Cosmos',
            ),
            NavigationDestination(
              icon: Icon(Icons.leaderboard_rounded, color: unselectedColor),
              selectedIcon: const Icon(
                Icons.leaderboard_rounded,
                color: Color(0xFF00E5FF),
              ),
              label: 'Ranks',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_rounded, color: unselectedColor),
              selectedIcon: const Icon(
                Icons.person_rounded,
                color: Color(0xFF00E5FF),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
