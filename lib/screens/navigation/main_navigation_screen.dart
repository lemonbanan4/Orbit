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
import '../../theme/orbit_tokens.dart';
import '../../theme/orbit_colors.dart';

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
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final navBgColor = isDark ? OrbitTokens.surface : Colors.white;
    final hairline = isDark
        ? OrbitTokens.hairline
        : const Color(0x14000000);
    final unselectedColor = isDark ? OrbitTokens.inkFaint : Colors.black38;
    // The app's actual brand accent (orange in dark mode, cyan in light) —
    // not a fixed teal, so the nav bar's active state matches whatever
    // accent the rest of the screen underneath it is using.
    final accent =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _OrbitNavBar(
        currentIndex: _currentIndex,
        onSelect: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: navBgColor,
        hairline: hairline,
        unselectedColor: unselectedColor,
        accent: accent,
        destinations: const [
          _OrbitNavDestination(Icons.home_rounded, 'Home'),
          _OrbitNavDestination(Icons.track_changes_rounded, 'Journey'),
          _OrbitNavDestination(Icons.mood_rounded, 'Cosmos'),
          _OrbitNavDestination(Icons.leaderboard_rounded, 'Ranks'),
          _OrbitNavDestination(Icons.person_rounded, 'Profile'),
        ],
      ),
    );
  }
}

class _OrbitNavDestination {
  final IconData icon;
  final String label;
  const _OrbitNavDestination(this.icon, this.label);
}

/// A minimal, one-accent bottom nav: no filled indicator pill, just an icon
/// opacity shift plus a small glow dot marking the active tab.
class _OrbitNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Color backgroundColor;
  final Color hairline;
  final Color unselectedColor;
  final Color accent;
  final List<_OrbitNavDestination> destinations;

  const _OrbitNavBar({
    required this.currentIndex,
    required this.onSelect,
    required this.backgroundColor,
    required this.hairline,
    required this.unselectedColor,
    required this.accent,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(destinations.length, (index) {
              final destination = destinations[index];
              final isActive = index == currentIndex;
              final color = isActive ? accent : unselectedColor;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? accent : Colors.transparent,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      Icon(destination.icon, color: color, size: 23),
                      const SizedBox(height: 3),
                      Text(
                        destination.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
