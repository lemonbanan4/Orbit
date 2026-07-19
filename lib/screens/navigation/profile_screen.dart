import 'package:flutter/material.dart';
import '../../theme/orbit_colors.dart';
import '../../utils/dev_overrides.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/routine_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:in_app_review/in_app_review.dart';
import '../settings/settings_screen.dart';
import '../stats/statistics_screen.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../achievements_screen.dart';
import '../../data/achievements_catalog.dart';
import '../habits/past_journeys_screen.dart';
import '../habits/skipped_sessions_screen.dart';
import '../../widgets/common/achievement_badge.dart';
import '../../widgets/common/profile_avatar.dart';
import '../../widgets/common/level_progress_card.dart';
import '../../widgets/common/profile_action_button.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../onboarding/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  bool _isPro = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


  @override
  void initState() {
    super.initState();
    _checkProStatus();
  }

  Future<void> _checkProStatus() async {
    if (DevOverrides.isProUnlocked) {
      setState(() => _isPro = true);
      return;
    }
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      if (customerInfo.entitlements.all["Orbit Pro"]?.isActive == true &&
          mounted) {
        setState(() => _isPro = true);
      }
    } catch (e) {
      debugPrint('Failed to check pro status: $e');
    }
  }

  Future<void> _pickAndUploadImage(User user) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      // If the user already has a photoURL from our Firebase Storage, delete the old one to save space
      if (user.photoURL != null && user.photoURL!.contains('firebasestorage')) {
        try {
          await FirebaseStorage.instance.refFromURL(user.photoURL!).delete();
        } catch (e) {
          debugPrint('Failed to delete old avatar: $e');
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance.ref().child(
            'avatars/${user.uid}_$timestamp.jpg',
          );

      final imageBytes = await image.readAsBytes();
      await storageRef.putData(imageBytes);

      final downloadUrl = await storageRef.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);
      await user
          .reload(); // Refresh local auth user state to trigger UI changes

      if (!mounted) return;
      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    }
  }

  void _showGuestSignUpSheet(BuildContext context, User user) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = context.read<RoutineProvider>().themeMode == 'Dark' ||
              context.read<RoutineProvider>().themeMode == 'System';
          final textColor = isDark ? Colors.white : const Color(0xFF1A1F36);
          final hintColor = isDark ? Colors.white54 : Colors.black54;
          final fillColor = isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF050112).withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Secure Your Account',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up to save your progress permanently and sync across devices.',
                        style: TextStyle(color: hintColor, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Name',
                          labelStyle: TextStyle(
                            color: hintColor,
                          ),
                          filled: true,
                          fillColor: fillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(
                            color: hintColor,
                          ),
                          filled: true,
                          fillColor: fillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(
                            color: hintColor,
                          ),
                          filled: true,
                          fillColor: fillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).extension<OrbitColors>()
                                        ?.orbColor1 ??
                                    const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (emailController.text.isEmpty ||
                                      passwordController.text.isEmpty) {
                                    return;
                                  }
                                  setModalState(() => isSaving = true);
                                  try {
                                    final credential =
                                        EmailAuthProvider.credential(
                                      email: emailController.text.trim(),
                                      password: passwordController.text,
                                    );
                                    await user.linkWithCredential(credential);
                                    await user.updateDisplayName(
                                      nameController.text.trim(),
                                    );
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .update({
                                      'name': nameController.text.trim(),
                                      'email': emailController.text.trim(),
                                      'isGuest': FieldValue.delete(),
                                    });
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Account secured successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to sign up: $e'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    setModalState(() => isSaving = false);
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Not logged in"));

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final accent =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);
    final subtitleColor = textColor.withValues(alpha: 0.6);
    final tileColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return BaseOrbitScreen(
      title: 'Profile',
      actions: [
        IconButton(
          icon: Icon(Icons.settings_rounded, color: textColor),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
      body: Stack(
        children: [
          // THE PARALLAX BACKGROUND LAYER
          AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              // Calculate the parallax offset
              double parallaxOffset = 0.0;
              if (_scrollController.hasClients) {
                parallaxOffset = _scrollController.offset * -0.1;
              }
              return Positioned(
                top: -50 + parallaxOffset,
                left: -10,
                right: -10,
                bottom: -50,
                child: Opacity(
                  opacity: isDark ? 0.4 : 0.1,
                  child: Image.asset(
                    'assets/images/nebula_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: accent),
                );
              }

              final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
              final isGuest = data['isGuest'] == true || user.isAnonymous;
              final name = data['name'] ?? user.displayName ?? 'Guest Explorer';
              final email = data['email'] ?? user.email ?? 'No email provided';
              // 'streakCount' is only ever set once, to 0, at signup
              // (auth_service.dart) and never updated again — the field
              // RoutineProvider actually maintains and persists on every
              // check-in is 'current_streak' (already used correctly by
              // statistics_screen.dart and leaderboard_tile.dart).
              final streakCount =
                  data['current_streak'] as int? ?? data['streakCount'] as int? ?? 0;
              final isProUser = data['isPro'] == true || _isPro;
              // Computed live, not read from the Firestore 'achievements'
              // array — that field was only ever initialized to [] at
              // signup and nothing in the app ever wrote to it, so this
              // section never showed for anyone.
              final achievements =
                  computeEarnedAchievements(context.watch<RoutineProvider>())
                      .toList();

              // 'xp' is RoutineProvider's spendable currency (streak
              // freezes, Nebula theme unlocks cost XP from it) -- Level is
              // actually tracked by TelemetryProvider via 'current_level'/
              // 'global_xp' (same fields journey_screen.dart reads), so
              // deriving Level from 'xp' via RewardPopup's formula meant
              // this screen disagreed with the Journey screen for the same
              // user, and spending in the store visibly lowered "Level".
              final level = data['current_level'] as int? ?? 1;
              final currentXp = data['global_xp'] as int? ?? 0;
              final xpToNextLevel = level * 150; // Matches TelemetryProvider
              final progress = currentXp / xpToNextLevel;

              return ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: ProfileAvatar(
                      photoUrl: user.photoURL,
                      isUploading: _isUploading,
                      onTap: () {
                        if (!_isUploading) _pickAndUploadImage(user);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isProUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accent),
                          ),
                          child: Text(
                            'PRO',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .shimmer(duration: 2.seconds, color: Colors.white),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subtitleColor, fontSize: 16),
                  ),
                  const SizedBox(height: 24),

                  // --- LEVEL & XP PROGRESS ---
                  LevelProgressCard(
                    level: level,
                    currentXp: currentXp,
                    xpToNextLevel: xpToNextLevel,
                    progress: progress,
                  ),
                  const SizedBox(height: 24),

                  // --- DETAILED STATISTICS BUTTON ---
                  ProfileActionButton(
                    title: 'Detailed Statistics',
                    subtitle: 'View consistency, XP & streaks',
                    icon: Icons.bar_chart_rounded,
                    accentColor: accent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const StatisticsScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- PAST JOURNEYS BUTTON ---
                  ProfileActionButton(
                    title: 'Past Journeys',
                    subtitle: 'View your completed paths',
                    icon: Icons.history_edu_rounded,
                    accentColor: Colors.purpleAccent,
                    isAnimated: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PastJourneysScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- SKIPPED SESSIONS BUTTON ---
                  ProfileActionButton(
                    title: 'Skipped Sessions',
                    subtitle: 'Review your past skips & reasons',
                    icon: Icons.history_toggle_off_rounded,
                    accentColor: Colors.orangeAccent,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SkippedSessionsScreen()),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- STREAK BADGE ---
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$streakCount Day Streak',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- ACHIEVEMENTS ---
                  if (achievements.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Achievements',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AchievementsScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'View All',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: achievements.map((key) {
                        final details = achievementsCatalog[key];
                        if (details == null) return const SizedBox.shrink();
                        return AchievementBadge(details: details);
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  if (isGuest) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Guest Account',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your progress is currently only saved locally. Sign up to secure your data and access it anywhere.',
                            style: TextStyle(color: subtitleColor),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                _showGuestSignUpSheet(context, user),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Sign Up & Save Data',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  ListTile(
                    onTap: () async {
                      final InAppReview inAppReview = InAppReview.instance;
                      if (await inAppReview.isAvailable()) {
                        inAppReview.requestReview();
                      }
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    tileColor: tileColor,
                    leading: const Icon(Icons.star_rate_rounded,
                        color: Colors.amber),
                    title: const Text('Review Orbit',
                        style: TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                    trailing:
                        Icon(Icons.chevron_right_rounded, color: subtitleColor),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    onTap: () async {
                      HapticFeedback.heavyImpact();
                      await context.read<AppAuthProvider>().signOut();
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true)
                            .pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: tileColor,
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: subtitleColor,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
