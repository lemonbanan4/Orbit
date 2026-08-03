import 'dart:math' as math;
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
import '../../services/notification_service.dart';
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

    // Sequenced (not fired in parallel) so a returning guest 3+ days in
    // never sees both the notification pre-prompt and the account-link
    // sheet stack on top of each other on first launch after this update.
    _runStartupPrompts();

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

  Future<void> _runStartupPrompts() async {
    await _checkNotificationPrompt();
    await _checkGuestLinkPrompt();
  }

  Future<void> _checkGuestLinkPrompt() async {
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

  // NotificationService.showNotificationPrePrompt()/checkAndRequestPermissions()
  // were fully built (a soft in-app ask, then the real OS prompt) but had
  // zero callers anywhere — main.dart schedules the daily 9AM reminder and
  // routine alarms unconditionally on every launch, but nothing ever
  // actually requested the OS permission for them outside of a user
  // manually opening the routine-alarms sheet. On Android 13+ that means
  // POST_NOTIFICATIONS silently stays ungranted and every scheduled
  // notification never appears, with no error surfaced anywhere.
  Future<void> _checkNotificationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenPrompt = prefs.getBool('has_seen_notification_prompt') ?? false;
    if (hasSeenPrompt) return;

    await prefs.setBool('has_seen_notification_prompt', true);
    if (mounted) {
      await NotificationService.showNotificationPrePrompt(context);
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
          _OrbitNavDestination('\u25D0', 'Home'), // ◐
          _OrbitNavDestination('\u25C8', 'Journey'), // ◈
          _OrbitNavDestination('\u2726', 'Cosmos'), // ✦
          _OrbitNavDestination('\u25A4', 'Ranks'), // ▤
          _OrbitNavDestination('\u25EF', 'Profile'), // ◯
        ],
      ),
    );
  }
}

/// The center nav "orb" — a teal→violet→gold gradient disc holding the Cosmos
/// glyph. It gives a one-shot pulse (scale + glow bloom) every time the user's
/// completed-habits-today count ticks up, so finishing a habit anywhere in the
/// app makes the orb come alive. Fully driven by real state
/// (RoutineProvider.habitsCompletedToday) — no fake animation.
class _CenterOrb extends StatefulWidget {
  final String glyph;
  const _CenterOrb({required this.glyph});

  @override
  State<_CenterOrb> createState() => _CenterOrbState();
}

class _CenterOrbState extends State<_CenterOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  int? _lastCount;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onCount(int count) {
    // Pulse only on a genuine increase (a habit was just completed), never on
    // the first read or on decrements (un-checking a habit).
    if (_lastCount != null && count > _lastCount!) {
      _pulse.forward(from: 0);
    }
    _lastCount = count;
  }

  @override
  Widget build(BuildContext context) {
    final count =
        context.select<RoutineProvider, int>((p) => p.habitsCompletedToday);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onCount(count);
    });

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = math.sin(_pulse.value * math.pi); // 0 -> 1 -> 0 bump
        final scale = 1 + 0.16 * t;
        final glow = 0.42 + 0.45 * t;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  OrbitTokens.teal,
                  OrbitTokens.violet,
                  OrbitTokens.gold,
                ],
              ),
              border: Border.all(color: Colors.white24, width: 1),
              boxShadow: [
                BoxShadow(
                  color: OrbitTokens.violet.withValues(alpha: glow),
                  blurRadius: 16 + 14 * t,
                  spreadRadius: 1 + 2 * t,
                ),
                BoxShadow(
                  color: OrbitTokens.teal.withValues(alpha: 0.22 + 0.3 * t),
                  blurRadius: 12,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.glyph,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrbitNavDestination {
  /// Geometric glyph from the redesign pitch (◐ ◈ ✦ ▤ ◯) rendered as
  /// text — deliberately not Material icons.
  final String glyph;
  final String label;
  const _OrbitNavDestination(this.glyph, this.label);
}

/// Orbit's bottom nav: a subtly gradient bar with a raised, glowing gradient
/// "orb" for Cosmos that floats above it. The orb pulses (scale + glow bloom)
/// every time a habit is completed (see [_CenterOrb]), so the nav comes alive
/// on interaction. The four flanking tabs stay as minimal glyph + label.
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

  static const double _barHeight = 62;
  static const double _stackHeight = 86; // bar + headroom for the raised orb
  static const double _orbSize = 50;

  @override
  Widget build(BuildContext context) {
    final topTint = Color.lerp(backgroundColor, Colors.white, 0.04)!;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _stackHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // The bar (subtle top-lit gradient + hairline).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: _barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [topTint, backgroundColor],
                  ),
                  border: Border(top: BorderSide(color: hairline)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(destinations.length, (index) {
                    return index == 2 ? _centerLabelCell() : _tabCell(index);
                  }),
                ),
              ),
            ),
            // Raised, glowing gradient orb for Cosmos, overlapping the bar top.
            Positioned(
              bottom: _barHeight - _orbSize / 2 - 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(2),
                child: _CenterOrb(glyph: destinations[2].glyph),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabCell(int index) {
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
                    ? [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 6)]
                    : null,
              ),
            ),
            SizedBox(
              height: 24,
              child: Center(
                child: Text(
                  destination.glyph,
                  style: TextStyle(
                    color: color,
                    fontSize: isActive ? 19 : 18,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Center cell holds only the label (the raised orb floats above it), spaced
  // to keep the label baseline aligned with the flanking tabs.
  Widget _centerLabelCell() {
    final isActive = currentIndex == 2;
    final color = isActive ? accent : unselectedColor;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10), // matches the active-dot + margin
            const SizedBox(height: 24), // matches the glyph slot
            const SizedBox(height: 3),
            Text(
              destinations[2].label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
