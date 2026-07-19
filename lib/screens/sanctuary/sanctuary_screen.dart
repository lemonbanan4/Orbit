import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../providers/routine_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../widgets/wisdom/wisdom_scroll_overlay.dart';
import '../../widgets/reward_popup.dart';
import '../paywall/premium_checker.dart';
import '../coaching/coaching_session_screen.dart';
import '../../theme/orbit_tokens.dart';
import '../../utils/dev_overrides.dart';
import 'bookmarked_wisdom_screen.dart';

class SanctuaryScreen extends StatefulWidget {
  const SanctuaryScreen({super.key});

  @override
  State<SanctuaryScreen> createState() => _SanctuaryScreenState();
}

class _SanctuaryScreenState extends State<SanctuaryScreen> {
  bool _isPro = false;
  // wisdomStreak was persisted to Firestore on every scroll-unroll but
  // never actually surfaced anywhere in the UI — loaded here so the CTA
  // card below can show it, same as the habit streak does on Home.
  int _wisdomStreak = 0;

  // Debug-only paywall bypass (was a hardcoded `true` that leaked the
  // bypass into release builds — DevOverrides is inert outside debug).
  final bool _isDeveloper = DevOverrides.isProUnlocked;

  @override
  void initState() {
    super.initState();
    _checkProStatus();
    _loadWisdomStreak();
  }

  Future<void> _loadWisdomStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final streak = doc.data()?['wisdomStreak'] as int?;
      if (streak != null && mounted) {
        setState(() => _wisdomStreak = streak);
      }
    } catch (e) {
      debugPrint('Failed to load wisdom streak: $e');
    }
  }

  Future<void> _checkProStatus() async {
    if (DevOverrides.isProUnlocked) {
      setState(() => _isPro = true);
      return;
    }
    // A transient RevenueCat/network blip here is indistinguishable from
    // "not subscribed" to the rest of this screen (fails closed, no error
    // UI) — a real Pro subscriber could silently see gated content. One
    // retry absorbs a one-off hiccup without adding a visible error state
    // for what's a background check, not a user-initiated action.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        CustomerInfo customerInfo = await Purchases.getCustomerInfo();
        if (customerInfo.entitlements.all["Orbit Pro"]?.isActive == true &&
            mounted) {
          setState(() => _isPro = true);
        }
        return;
      } catch (e) {
        debugPrint('Failed to check pro status (attempt $attempt): $e');
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  // The popup used to show "+500 XP" without any XP actually being
  // granted. Extracted to its own method (rather than inlined several
  // conditionals deep in _openSacredScroll) so the mounted/context guards
  // are unambiguous to both readers and the analyzer.
  Future<void> _grantSageBadgeReward() async {
    if (!mounted) return;
    final telemetryProvider = context.read<TelemetryProvider>();
    await telemetryProvider.awardXp(500);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    RewardPopup.show(
      context,
      title: "Sage Badge Unlocked!",
      xpEarned: 500,
      currentTotalXp: telemetryProvider.globalXp,
    );
  }

  // Categories confirmed to have scroll content in the wisdom_library
  // collection. Onboarding offers 24 interests but the library only has
  // docs for these — used as the retry pool when a user's own interest
  // maps to a doc that doesn't exist (e.g. 'Better Sleep' -> better_sleep),
  // which previously dead-ended in "The stars are quiet today." every
  // single time for users whose picked interests all lacked content.
  static const List<String> _stockedWisdomCategories = [
    'stoicism',
    'creativity',
    'mindfulness',
    'productivity',
    'anxiety_stress',
  ];

  String _pickWisdomCategory(List<String> userInterests) {
    if (userInterests.isEmpty) {
      final fallbacks = [..._stockedWisdomCategories];
      fallbacks.shuffle();
      return fallbacks.first;
    }
    userInterests.shuffle();
    return userInterests.first
        .toLowerCase()
        .replaceAll(' & ', '_')
        .replaceAll(' ', '_');
  }

  Future<void> _openSacredScroll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var loadingDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: OrbitTokens.teal),
      ),
    );

    try {
      final routineProvider = context.read<RoutineProvider>();
      var category = _pickWisdomCategory(routineProvider.interests);
      var doc = await FirebaseFirestore.instance
          .collection('wisdom_library')
          .doc(category)
          .get();

      // If the interest-derived category has no library doc, retry once
      // with a category known to be stocked instead of showing the
      // "stars are quiet" dead end.
      if (!doc.exists && !_stockedWisdomCategories.contains(category)) {
        final fallbacks = [..._stockedWisdomCategories]..shuffle();
        category = fallbacks.first;
        doc = await FirebaseFirestore.instance
            .collection('wisdom_library')
            .doc(category)
            .get();
      }

      String wisdomText = "The stars are quiet today. Check back later.";
      final data = doc.data();
      if (doc.exists && data != null && data['scrolls'] != null) {
        List<dynamic> scrolls = data['scrolls'];
        scrolls.shuffle();
        wisdomText = scrolls.first.toString();
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      int streak = userData?['wisdomStreak'] ?? 0;
      final lastWisdomTimestamp = userData?['lastWisdomDate'] as Timestamp?;

      if (mounted) {
        Navigator.pop(context);
        loadingDialogShowing = false;

        showDialog(
          context: context,
          barrierColor: Colors.black87,
          builder: (context) => WisdomScrollOverlay(
            category: category,
            content: wisdomText,
            isPro: _isPro,
          ),
        );

        if (_isPro) {
          // lastWisdomDate was written on every unroll but never actually
          // checked -- the streak incremented per tap, not per day, so
          // rapidly re-tapping "Unroll Daily Wisdom" could farm the 5-day
          // Sage Badge in one sitting. Only advance once per calendar day,
          // and reset (rather than continue) if a day was skipped, matching
          // how habit streaks already behave elsewhere in the app.
          final today = DateTime.now();
          final todayKey = DateTime(today.year, today.month, today.day);
          final lastDate = lastWisdomTimestamp?.toDate();
          final lastKey = lastDate == null
              ? null
              : DateTime(lastDate.year, lastDate.month, lastDate.day);

          if (lastKey != todayKey) {
            final daysSinceLast = lastKey == null
                ? null
                : todayKey.difference(lastKey).inDays;
            final newStreak = (daysSinceLast == null || daysSinceLast > 1)
                ? 1
                : streak + 1;

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
                  'wisdomStreak': newStreak,
                  'lastWisdomDate': FieldValue.serverTimestamp(),
                });
            if (mounted) setState(() => _wisdomStreak = newStreak);
            if (newStreak == 5) {
              unawaited(_grantSageBadgeReward());
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Sacred Scroll error: $e');
      if (mounted) {
        // Only pop the loading spinner if it's still the thing showing —
        // the WisdomScrollOverlay itself might be up if the streak update
        // (a non-critical follow-up write) is what failed.
        if (loadingDialogShowing) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the Sacred Scroll. Please try again.')),
        );
      }
    }
  }

  void _openJournal(String activeCategory) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "JournalOfDestiny",
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: _JournalBottomSheet(activeCategory: activeCategory),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutQuart),
                ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitTokens.ground,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1),
                    radius: 1.3,
                    colors: [
                      OrbitTokens.violet.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            "The Sanctuary",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.bookmark_rounded,
                            color: Colors.white,
                          ),
                          tooltip: 'Bookmarked Wisdom',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const BookmarkedWisdomScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(24.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          _openSacredScroll();
                        },
                        child:
                            Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: const LinearGradient(
                                      colors: [
                                        OrbitTokens.violet,
                                        OrbitTokens.teal,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: OrbitTokens.teal.withValues(alpha: 0.5),
                                        blurRadius: 30,
                                        spreadRadius: -5,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.auto_stories_rounded,
                                              color: Colors.white,
                                              size: 32,
                                            ),
                                            SizedBox(width: 16),
                                            Text(
                                              "Unroll Daily Wisdom",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_wisdomStreak > 0) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            "🔥 $_wisdomStreak day streak",
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.85),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .shimmer(
                                  duration: 3.seconds,
                                  color: Colors.white30,
                                )
                                .scaleXY(
                                  begin: 1.0,
                                  end: 1.02,
                                  duration: 2.seconds,
                                  curve: Curves.easeInOut,
                                ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        "The Cosmic Mirror",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          // MAGIC FIX: Capital N for 'Night'
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CoachingSessionScreen(
                                sessionType: 'Night',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F2027), Color(0xFF203A43)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: OrbitTokens.teal.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: OrbitTokens.teal.withValues(alpha: 0.2),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.psychology_rounded,
                                  color: OrbitTokens.teal,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Consult the Mirror",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Let the AI Fairy guide your nightly reflection.",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white38,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        "Cosmic Soundscapes",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 140,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildAudioCard(
                              context,
                              "Deep Orbit Focus",
                              "Binaural",
                              Icons.headphones_rounded,
                              const [Color(0xFF141E30), Color(0xFF243B55)],
                              "assets/audio/deep_orbit_focus.mp3",
                            ),
                            _buildAudioCard(
                              context,
                              "Nebula Sleep",
                              "Ambient",
                              Icons.bedtime_rounded,
                              const [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                              "assets/audio/nebula_sleep.mp3",
                            ),
                            _buildAudioCard(
                              context,
                              "Morning Star",
                              "Energy",
                              Icons.wb_sunny_rounded,
                              const [Color(0xFFF09819), Color(0xFFFF512F)],
                              "assets/audio/morning_star.mp3",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        "Reflection",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _openJournal(
                            "General",
                          ); // Pass a default category context for journal entries
                        },
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF512F,
                                  ).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_note_rounded,
                                  color: Color(0xFFFF512F),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Journal of Destiny",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Log your cosmic insights and daily growth.",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white38,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    List<Color> gradient,
    String audioPath,
  ) {
    final routineProvider = context.watch<RoutineProvider>();
    bool isPlaying =
        routineProvider.isPlayingAmbient &&
        routineProvider.selectedAudioTrack.contains(audioPath);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();

        // ADMIN BYPASS LOGIC
        if (!_isPro && !_isDeveloper) {
          PremiumChecker.requirePro(
            context,
            onAccessGranted: () => setState(() => _isPro = true),
          );
          return;
        }

        final provider = context.read<RoutineProvider>();
        if (isPlaying) {
          provider.toggleAmbientAudio();
        } else {
          provider.setAmbientTrack(audioPath);
          if (!provider.isPlayingAmbient) {
            provider.toggleAmbientAudio();
          }
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPlaying ? OrbitTokens.teal : Colors.transparent,
            width: 2,
          ),
          boxShadow: isPlaying
              ? [
                  BoxShadow(
                    color: gradient.last.withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                if (isPlaying)
                  const Icon(
                        Icons.graphic_eq_rounded,
                        color: OrbitTokens.teal,
                        size: 20,
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 0.8, end: 1.2, duration: 400.ms),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalBottomSheet extends StatefulWidget {
  final String activeCategory;

  const _JournalBottomSheet({required this.activeCategory});

  @override
  State<_JournalBottomSheet> createState() => _JournalBottomSheetState();
}

class _JournalBottomSheetState extends State<_JournalBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSaving = false;
  String? _editingEntryId;
  final Set<String> _deletingIds = {};

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Padding bottom ensures the bottom sheet moves up with the keyboard
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: OrbitTokens.ground, // Matches scaffold background
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(
            color: OrbitTokens.teal.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Journal of Destiny",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_editingEntryId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Editing Previous Entry",
                      style: TextStyle(
                        color: OrbitTokens.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _controller.clear();
                        setState(() => _editingEntryId = null);
                      },
                      child: const Text(
                        "Cancel Edit",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              focusNode: _focusNode,
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Log your cosmic insights...",
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrbitTokens.teal,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        // 1 Snag the current text input value cleanly
                        final String entryText = _controller.text.trim();
                        if (entryText.isEmpty) {
                          return; // Guard clause prevents saving blank strings!
                        }

                        // 2 Lock the UI button down so they cant double-tap submit
                        setState(() => _isSaving = true);
                        HapticFeedback.mediumImpact();

                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          // Use the currently edited document ID, or generate a new one for today
                          final String targetDocId =
                              _editingEntryId ??
                              DateTime.now().toIso8601String().split('T')[0];

                          try {
                            // Dispatch the transmission packet straight to the database
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('journal_entries')
                                .doc(targetDocId)
                                .set({
                                  'content': entryText,
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'sourceCategory': widget
                                      .activeCategory, // Connects it to your UI entry point category
                                }, SetOptions(merge: true));

                            // Safely check if the user is still looking at this screen before closing out
                            if (context.mounted) {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(context);
                              _controller.clear();
                              setState(() {
                                _isSaving = false;
                                _editingEntryId = null;
                              });

                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text("Entry sealed in the stars. ✨"),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: OrbitTokens.violet,
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint("💥 FIRESTORE JOURNAL SAVE FAILURE: $e");

                            // If it fails unlock the button so they can try again
                            if (context.mounted) {
                              setState(() => _isSaving = false);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Cosmic Interference: Failed to save entry.",
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _editingEntryId != null ? "UPDATE ENTRY" : "SAVE ENTRY",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Previous Entries",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (user != null)
              Flexible(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('journal_entries')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        "Cosmic interference loading entries.",
                        style: TextStyle(color: Colors.redAccent),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: OrbitTokens.teal,
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Text(
                        "No entries yet. Start writing your destiny.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final content = data['content'] as String? ?? '';
                        final timestamp = data['timestamp'] as Timestamp?;
                        final dateString = timestamp != null
                            ? "${timestamp.toDate().month}/${timestamp.toDate().day}/${timestamp.toDate().year}"
                            : "Just now";

                        final bool isDeleting = _deletingIds.contains(
                          docs[index].id,
                        );

                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isDeleting ? 0.0 : 1.0,
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutBack,
                            child: isDeleting
                                ? const SizedBox(
                                    width: double.infinity,
                                    height: 0,
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              dateString,
                                              style: const TextStyle(
                                                color: OrbitTokens.teal,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit_note_rounded,
                                                    size: 20,
                                                  ),
                                                  color: Colors.white54,
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed: () {
                                                    HapticFeedback.lightImpact();
                                                    setState(() {
                                                      _controller.text =
                                                          content;
                                                      _editingEntryId =
                                                          docs[index].id;
                                                    });
                                                    _focusNode.requestFocus();
                                                  },
                                                ),
                                                const SizedBox(width: 12),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 20,
                                                  ),
                                                  color: Colors.white54,
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed: () async {
                                                    HapticFeedback.lightImpact();
                                                    final bool?
                                                    confirmDelete = await showDialog<bool>(
                                                      context: context,
                                                      builder: (BuildContext context) {
                                                        return AlertDialog(
                                                          backgroundColor:
                                                              OrbitTokens.surface, // Deep premium navy
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  16,
                                                                ),
                                                            side: BorderSide(
                                                              color:
                                                                  OrbitTokens.teal.withValues(
                                                                    alpha: 0.3,
                                                                  ),
                                                            ),
                                                          ),
                                                          title: const Text(
                                                            "Delete Entry?",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                          content: const Text(
                                                            "Are you sure you want to permanently delete this cosmic insight?",
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(false),
                                                              child: const Text(
                                                                "Cancel",
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white54,
                                                                ),
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(true),
                                                              child: const Text(
                                                                "Delete",
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .redAccent,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );

                                                    if (confirmDelete != true) {
                                                      return;
                                                    }

                                                    setState(
                                                      () => _deletingIds.add(
                                                        docs[index].id,
                                                      ),
                                                    );
                                                    // Give the local UI time to animate the collapse before the stream updates
                                                    await Future.delayed(
                                                      const Duration(
                                                        milliseconds: 300,
                                                      ),
                                                    );

                                                    try {
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('users')
                                                          .doc(user.uid)
                                                          .collection(
                                                            'journal_entries',
                                                          )
                                                          .doc(docs[index].id)
                                                          .delete();
                                                    } catch (e) {
                                                      debugPrint(
                                                        "💥 Failed to delete entry: $e",
                                                      );
                                                      if (context.mounted) {
                                                        setState(
                                                          () => _deletingIds
                                                              .remove(
                                                                docs[index].id,
                                                              ),
                                                        );
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              "Cosmic Interference: Failed to delete entry.",
                                                            ),
                                                            backgroundColor:
                                                                Colors
                                                                    .redAccent,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          content,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
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
