import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'profile_screen.dart';
import '../social/leaderboard_screen.dart';
import '../habit_dashboard_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../widgets/telemetry_levelup_dialog.dart';
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

    // A health-linked habit can complete via a silent background sync with
    // no screen-specific tap to hang the Telemetry award off of (see
    // RoutineProvider.pendingHealthTelemetryXp) -- this shell is the one
    // widget guaranteed to be mounted regardless of which tab is active, so
    // it's the only reliable place to consume that signal. Selector (not
    // context.watch, used for the rest of this build()) so this only
    // rebuilds on the specific int changing, not on every unrelated
    // RoutineProvider.notifyListeners() call -- the `child` Scaffold below
    // is built once and passed through untouched otherwise.
    return Selector<RoutineProvider, int>(
      selector: (_, p) => p.pendingHealthTelemetryXp,
      builder: (context, pendingHealthXp, child) {
        if (pendingHealthXp > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) return;
            final routineProvider = context.read<RoutineProvider>();
            routineProvider.clearPendingHealthTelemetryXp();
            final telemetry = context.read<TelemetryProvider>();
            final didLevelUp = await telemetry.awardXp(pendingHealthXp);
            if (!context.mounted) return;
            final newMilestones = telemetry.checkMilestoneUnlocks(
              routineProvider.currentStreak,
            );
            if (didLevelUp) {
              TelemetryLevelUpDialog.show(context, telemetry.currentLevel);
            } else if (newMilestones.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'A health sync just unlocked a new streak milestone! 🌟',
                  ),
                ),
              );
            }
          });
        }
        return child!;
      },
      child: Scaffold(
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
  final VoidCallback onTap;
  const _CenterOrb({required this.glyph, required this.onTap});

  @override
  State<_CenterOrb> createState() => _CenterOrbState();
}

class _CenterOrbState extends State<_CenterOrb>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  // Separate from _pulse (a one-shot "bump" on habit completion) -- this
  // ramps up on tap-down/hold and eases back down on release, so tapping
  // or holding the orb gives it the same glow language without fighting
  // the completion pulse's own timing.
  late final AnimationController _pressGlow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    reverseDuration: const Duration(milliseconds: 350),
  );
  int? _lastCount;

  @override
  void dispose() {
    _pulse.dispose();
    _pressGlow.dispose();
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressGlow.forward(),
      onTapUp: (_) => _pressGlow.reverse(),
      onTapCancel: () => _pressGlow.reverse(),
      onLongPressEnd: (_) => _pressGlow.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _pressGlow]),
        builder: (context, _) {
          final pulseT = math.sin(_pulse.value * math.pi); // 0 -> 1 -> 0 bump
          final t = math.max(pulseT, _pressGlow.value);
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
      ),
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

/// Paints the nav bar as a gradient panel with a circular notch carved out of
/// its top-center edge (the "U" that cradles the Cosmos orb), plus a hairline
/// that follows the notch curve. Uses [CircularNotchedRectangle] -- the same
/// shape Material's BottomAppBar uses to dock a FAB.
class _NotchedBarPainter extends CustomPainter {
  final double notchRadius;
  final Gradient gradient;
  final Color hairline;

  const _NotchedBarPainter({
    required this.notchRadius,
    required this.gradient,
    required this.hairline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final host = Offset.zero & size;
    // Guest circle sits on the top edge (centre y = 0) so the notch cuts down
    // into the bar and cradles the orb's lower half.
    final guest = Rect.fromCircle(
      center: Offset(size.width / 2, 0),
      radius: notchRadius,
    );
    final path = const CircularNotchedRectangle().getOuterPath(host, guest);
    canvas.drawPath(path, Paint()..shader = gradient.createShader(host));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = hairline,
    );
  }

  @override
  bool shouldRepaint(_NotchedBarPainter old) =>
      old.notchRadius != notchRadius ||
      old.gradient != gradient ||
      old.hairline != hairline;
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
            // The bar, with a circular "U" notch cradling the center orb.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomPaint(
                painter: _NotchedBarPainter(
                  notchRadius: _orbSize / 2 + 7,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [topTint, backgroundColor],
                  ),
                  hairline: hairline,
                ),
                child: SizedBox(
                  height: _barHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(destinations.length, (index) {
                      return index == 2 ? _centerLabelCell() : _tabCell(index);
                    }),
                  ),
                ),
              ),
            ),
            // Glowing gradient orb nestled in the notch (centered on the bar top
            // so its lower half sits in the cradle, upper half floats above).
            Positioned(
              bottom: _barHeight - _orbSize / 2,
              child: Semantics(
                button: true,
                selected: currentIndex == 2,
                label: destinations[2].label,
                onTap: () => onSelect(2),
                // _CenterOrb owns its own GestureDetector now (needs
                // onTapDown/onTapUp for the press-glow effect, which would
                // otherwise compete with an outer one in the gesture arena
                // and risk the outer onTap never firing), so this just
                // wraps it for semantics rather than also handling the tap.
                child: ExcludeSemantics(
                  child: _CenterOrb(
                    glyph: destinations[2].glyph,
                    onTap: () => onSelect(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // destinations[] carries no semantic-role info of its own (glyph is a
  // decorative Unicode character, not real text -- VoiceOver would
  // otherwise try to read it literally, e.g. "circle with left half
  // black"), so each cell is wrapped in one Semantics node with the
  // button/selected traits and the plain-English label, with the visual
  // subtree excluded from the tree entirely to avoid a second, redundant
  // announcement of the same label Text widget underneath.
  Widget _tabCell(int index) {
    final destination = destinations[index];
    final isActive = index == currentIndex;
    final color = isActive ? accent : unselectedColor;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: destination.label,
        onTap: () => onSelect(index),
        child: ExcludeSemantics(
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
        ),
      ),
    );
  }

  // Center cell holds only the label (the orb sits in the notch above it),
  // spaced to keep the label baseline aligned with the flanking tabs. Also
  // independently focusable/announced for VoiceOver (not excluded) since
  // it's a real, separately-tappable hit region from the orb above it, not
  // purely decorative.
  Widget _centerLabelCell() {
    final isActive = currentIndex == 2;
    final color = isActive ? accent : unselectedColor;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: destinations[2].label,
        onTap: () => onSelect(2),
        child: ExcludeSemantics(
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
        ),
      ),
    );
  }
}
