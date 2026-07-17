import 'package:flutter/material.dart';
import '../../theme/orbit_colors.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/premium_glass_card.dart';

class InvitePartnerScreen extends StatefulWidget {
  const InvitePartnerScreen({super.key});

  @override
  State<InvitePartnerScreen> createState() => _InvitePartnerScreenState();
}

class _InvitePartnerScreenState extends State<InvitePartnerScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLinking = false;

  Future<void> _linkPartner() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-character code.')),
      );
      return;
    }

    setState(() => _isLinking = true);
    FocusScope.of(context).unfocus();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("Not logged in");

      // The lookup (matching a code against another user's uid prefix) and
      // the link-doc write both have to happen server-side — firestore.rules
      // only lets a user read their own document and has no client-write
      // rule for the top-level 'links' collection at all.
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('linkPartner')
          .call({'code': code});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Successfully linked orbits! 🚀'),
              backgroundColor: Colors.greenAccent),
        );
        Navigator.pop(context);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        final message = switch (e.code) {
          'not-found' => "That code isn't valid — double-check it and try again.",
          'already-exists' => "You're already linked with this partner.",
          'invalid-argument' => 'Enter a valid partner code.',
          'unauthenticated' => 'You need to be logged in to link a partner.',
          _ => e.message ?? 'Could not reach the Orbit servers.',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to link: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final myCode = user?.uid.substring(0, 6).toUpperCase() ?? "------";
    final accent =
        Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);

    return BaseOrbitScreen(
      title: 'Partner Link',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.hub_rounded, size: 80, color: accent)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.9, end: 1.1, duration: 2.seconds)
                .shimmer(color: Colors.white, duration: 3.seconds),
            const SizedBox(height: 24),
            const Text(
              'Link Your Orbits',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your code with a partner or enter theirs below to link your accounts and track habits together!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 40),
            PremiumGlassCard(
              child: Column(
                children: [
                  const Text('YOUR CODE',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Clipboard.setData(ClipboardData(text: myCode));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Code copied to clipboard!')));
                    },
                    child: Text(myCode,
                        style: TextStyle(
                            color: accent,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8.0)),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap to copy',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ).animate().fade(duration: 500.ms).slideY(begin: 0.2),
            const SizedBox(height: 40),
            TextField(
              controller: _codeController,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 4.0,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'ENTER PARTNER CODE',
                hintStyle: const TextStyle(
                    color: Colors.white24, letterSpacing: 2.0, fontSize: 14),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                counterText: '', // Hides the 0/6 text
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: _isLinking ? null : _linkPartner,
                icon: _isLinking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.link_rounded),
                label: Text(_isLinking ? 'Linking...' : 'Link Partner Account',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
