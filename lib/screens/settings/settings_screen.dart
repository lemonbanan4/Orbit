import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/routine_provider.dart';
import 'notifications_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/settings_tile.dart';
import 'package:in_app_review/in_app_review.dart';
import '../features/nebula_forge_screen.dart';
import '../../theme/orbit_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  // The app's actual brand accent (orange in dark mode, cyan in light) —
  // settings renders in both themes via BaseOrbitScreen, so every accent
  // here must follow the theme rather than a fixed hex.
  Color get _accent =>
      Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
      const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update Auth record
        await user.updateDisplayName(_nameController.text.trim());
        // Update Firestore record
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'name': _nameController.text.trim()});
        await user.reload(); // Refresh local state

        if (mounted) {
          FocusScope.of(context).unfocus(); // Dismiss keyboard
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile updated successfully!'),
              backgroundColor: _accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> openSubscriptionManagement() async {
    try {
      // This pops up a native sheet handled entirely by RevenueCat
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      debugPrint("Failed to open Customer Center: $e");
    }
  }

  void _showRedeemDialog() {
    final codeController = TextEditingController();
    bool isRedeeming = false;
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Redeem Invite Code', style: TextStyle(color: textColor)),
          content: TextField(
            controller: codeController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Enter 6-digit code',
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
              filled: true,
              fillColor: textColor.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: textColor.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
              ),
              onPressed: isRedeeming
                  ? null
                  : () async {
                      if (codeController.text.trim().isEmpty) return;
                      setDialogState(() => isRedeeming = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) throw Exception("Not logged in");

                        final code = codeController.text.trim().toUpperCase();
                        await FirebaseFunctions.instanceFor(
                          region: 'europe-west1',
                        ).httpsCallable('redeemReferralCode').call({
                          'code': code,
                        });

                        if (mounted && context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Success! You and your friend both got 30 days of Orbit Pro! 🎉',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } on FirebaseFunctionsException catch (e) {
                        setDialogState(() => isRedeeming = false);
                        if (context.mounted) {
                          final message = switch (e.code) {
                            'not-found' => 'That code isn\'t valid — double-check it and try again.',
                            'invalid-argument' => 'Enter a valid invite code.',
                            'unauthenticated' => 'You need to be logged in to redeem a code.',
                            _ => e.message ?? 'Could not reach the Orbit servers.',
                          };
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isRedeeming = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to redeem: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
              child: isRedeeming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Redeem',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    HapticFeedback.heavyImpact();
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone and will erase all your progress.',
          style: TextStyle(color: textColor.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: textColor.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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

    if (confirm == true && mounted) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .delete();
          await user.delete();
          if (mounted) {
            Navigator.of(context).pop(); // Go back before state changes
            context.read<AppAuthProvider>().signOut();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete account. You may need to re-login and try again. Error: $e',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> sendSupportEmail(
    BuildContext context,
    String userMessage,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'No Email Provided';
    final uid = user?.uid ?? 'Unknown UID';

    try {
      await FirebaseFirestore.instance.collection('mail').add({
        'to': 'contact@orbitroutine.com', // Your support inbox
        'message': {
          'subject': 'Orbit Support Request from $userEmail',
          'html':
              '''
          <h3>New Support Request</h3>
          <p><strong>User:</strong> $userEmail</p>
          <p><strong>UID:</strong> $uid</p>
          <hr>
          <p><strong>Message:</strong></p>
          <p>$userMessage</p>
        ''',
          // This makes it so when you hit "Reply" in your inbox, it goes to the user
          'replyTo': userEmail,
        },
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support request sent successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
      }
    }
  }

  void _showContactSupportDialog() {
    final messageController = TextEditingController();
    bool isSending = false;
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Contact Support', style: TextStyle(color: textColor)),
          content: TextField(
            controller: messageController,
            style: TextStyle(color: textColor),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'How can we help you?',
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
              filled: true,
              fillColor: textColor.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: textColor.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
              ),
              onPressed: isSending
                  ? null
                  : () async {
                      if (messageController.text.trim().isEmpty) return;
                      setDialogState(() => isSending = true);
                      await sendSupportEmail(
                        context,
                        messageController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Send',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final subtitleColor = textColor.withValues(alpha: 0.6);

    return BaseOrbitScreen(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            'Edit Profile',
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          PremiumGlassCard(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    labelStyle: TextStyle(color: subtitleColor),
                    prefixIcon: Icon(
                      Icons.person_rounded,
                      color: subtitleColor,
                    ),
                    filled: true,
                    fillColor: textColor.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Save Changes',
                  isLoading: _isSaving,
                  onPressed: _updateProfile,
                ),
                Divider(color: textColor.withValues(alpha: 0.1), height: 1),
                Consumer<RoutineProvider>(
                  builder: (context, routineProvider, _) => SwitchListTile(
                    value: routineProvider.confettiEnabled,
                    activeThumbColor: _accent,
                    title: Text(
                      'Enable Confetti',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      routineProvider.setConfetti(val);
                    },
                    secondary: Icon(
                      Icons.celebration_rounded,
                      color: textColor,
                    ),
                  ),
                ),
                Divider(color: textColor.withValues(alpha: 0.1), height: 1),
                SettingsTile(
                  onTap: _confirmDeleteAccount,
                  icon: Icons.person_remove_rounded,
                  iconColor: Colors.redAccent,
                  title: 'Delete Account',
                  titleColor: Colors.redAccent,
                  trailing: const SizedBox.shrink(),
                ),
              ],
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
          if (kDebugMode) ...[
            const SizedBox(height: 40),
            TextButton(
              onPressed: () {
                // This will force a fatal crash
                FirebaseCrashlytics.instance.crash();
              },
              child: const Text("Throw Test Crash"),
            ),
          ],
          const SizedBox(height: 40),
          Text(
            'Account',
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
                // SettingsTile(
                //   onTap: () {
                //     HapticFeedback.selectionClick();
                //     AvatarPickerSheet.show(context);
                //   },
                //   icon: Icons.smart_toy_rounded,
                //   title: 'AI Coach Avatar',
                // ),
                // Divider(
                //   color: textColor.withValues(alpha: 0.1),
                //   height: 1,
                // ),
                SettingsTile(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NebulaForgeScreen(
                          sourcePhase: "Settings Module",
                        ),
                      ),
                    );
                  },
                  icon: Icons.hub_rounded,
                  title: 'Nebula Forge Analytics',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _accent),
                            ),
                            child: Text(
                              'PRO',
                              style: TextStyle(
                                color: _accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .shimmer(duration: 2.seconds, color: textColor),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: textColor.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
                Consumer<RoutineProvider>(
                  builder: (context, provider, child) {
                    return SwitchListTile(
                      title: const Text(
                        'Enable All Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Temporarily pause or resume All Orbit reminders.',
                        style: TextStyle(color: Colors.white54),
                      ),
                      activeThumbColor: _accent,
                      value: provider.allNotifsEnabled,
                      onChanged: (bool value) {
                        provider.setAllNotifsEnabled(value);
                      },
                    );
                  },
                ),
                Consumer<RoutineProvider>(
                  builder: (context, provider, child) {
                    return SwitchListTile(
                      title: const Text(
                        'Evening Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Get a daily digest of your completed habits.',
                        style: TextStyle(color: Colors.white54),
                      ),
                      activeThumbColor: _accent,
                      value: provider.dailySummaryNotifs,
                      onChanged: (bool value) {
                        HapticFeedback.lightImpact();
                        provider.setDailySummaryNotifs(value);
                      },
                    );
                  },
                ),
                Divider(color: textColor.withValues(alpha: 0.1), height: 1),
                SettingsTile(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                ),
                Divider(color: textColor.withValues(alpha: 0.1), height: 1),
                SettingsTile(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    Navigator.of(context).pop(); // Go back before signing out
                    context.read<AppAuthProvider>().signOut();
                  },
                  icon: Icons.logout_rounded,
                  iconColor: Colors.redAccent,
                  title: 'Sign Out',
                  titleColor: Colors.redAccent,
                ),
              ],
            ),
          ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
          const SizedBox(height: 40),
          Text(
            'Spread the Word',
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
                SettingsTile(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    final user = FirebaseAuth.instance.currentUser;
                    final refCode = user != null
                        ? user.uid.substring(0, 6).toUpperCase()
                        : 'ORBIT';
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            'I use Orbit to master my daily habits! Use my invite code $refCode to unlock 30 Days of Orbit Pro for free! 🚀 https://orbit.app/invite',
                      ),
                    );
                  },
                  icon: Icons.favorite_rounded,
                  iconColor: Colors.pinkAccent,
                  title: 'Refer a Friend',
                  subtitle: 'Give 30 Days Pro, Get 30 Days Pro',
                  trailing: Icon(
                    Icons.ios_share_rounded,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
                Divider(color: textColor.withValues(alpha: 0.1), height: 1),
                SettingsTile(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showRedeemDialog();
                  },
                  icon: Icons.redeem_rounded,
                  iconColor: _accent,
                  title: 'Redeem Code',
                ),
                Divider(color: textColor.withValues(alpha: 0.1), height: 1),
                SettingsTile(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    try {
                      final InAppReview inAppReview = InAppReview.instance;
                      if (await inAppReview.isAvailable()) {
                        await inAppReview.requestReview();
                      } else {
                        await inAppReview.openStoreListing();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thank you for your support! 🌟'),
                          ),
                        );
                      }
                    }
                  },
                  icon: Icons.star_rounded,
                  iconColor: Colors.amber,
                  title: 'Review Orbit',
                  subtitle: 'Help us grow by leaving a review',
                  trailing: const Icon(Icons.star_rounded, color: Colors.amber)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.2, duration: 800.ms)
                      .shimmer(color: textColor, duration: 2.seconds),
                ),
                Divider(color: textColor.withValues(alpha: 0.1), height: 1),
                SettingsTile(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showContactSupportDialog();
                  },
                  icon: Icons.support_agent_rounded,
                  iconColor: _accent,
                  title: 'Contact Support',
                  subtitle: 'Need help or have feedback?',
                ),
              ],
            ),
          ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }
}
