import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GuestAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final int animationDelay;

  const GuestAuthButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white70, strokeWidth: 2))
          : const Text(
              'Continue as Guest',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline),
            ),
    )
        .animate()
        .fade(duration: 500.ms, delay: animationDelay.ms)
        .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic);
  }
}
