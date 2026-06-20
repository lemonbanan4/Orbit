import 'package:flutter/material.dart';
import '../screens/paywall/premium_checker.dart';

class PremiumPopups {
  static void showScrollExpired(BuildContext context, VoidCallback onRecover) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_disabled_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Scroll Expired', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'You missed your window to claim this scroll! Free scrolls expire after 48 hours.\n\nUpgrade to Orbit Pro to recover expired scrolls and get a new scroll every 24 hours!',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Dismiss', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              PremiumChecker.requirePro(context, onAccessGranted: onRecover);
            },
            child: const Text('Recover with Pro',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
