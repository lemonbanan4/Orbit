import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dart:io' show Platform;
import '../screens/onboarding/email_link_screen.dart';

class AccountLinkPromptSheet extends StatelessWidget {
  const AccountLinkPromptSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AppAuthProvider>();

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Color(0xFF0A102A), // Orbit dark theme background
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.security_rounded,
              color: Color(0xFF00E5FF),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              "Secure Your Progress",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You're currently using a guest account. Link an account to make sure your habits and streak are safely backed up to the cosmos!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Apple Linking Button (Hide on Android/Web unless configured)
            if (Platform.isIOS || Platform.isMacOS) ...[
              _buildLinkButton(
                context,
                icon: Icons.apple,
                label: "Link with Apple",
                color: Colors.white,
                textColor: Colors.black,
                onTap: () async {
                  Navigator.pop(context);
                  await authProvider.signInWithApple();
                },
              ),
              const SizedBox(height: 12),
            ],

            // Google Linking Button
            _buildLinkButton(
              context,
              icon: Icons.g_mobiledata_rounded,
              label: "Link with Google",
              color: Colors.white,
              textColor: Colors.black,
              onTap: () async {
                Navigator.pop(context);
                await authProvider.signInWithGoogle();
              },
            ),
            const SizedBox(height: 12),

            // Email Linking Button
            _buildLinkButton(
              context,
              icon: Icons.email_rounded,
              label: "Link with Email",
              color: Colors.white.withValues(alpha: 0.1),
              textColor: Colors.white,
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmailLinkScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
