import 'package:flutter/material.dart';
import '../../theme/orbit_tokens.dart';

/// The single, full-width gradient CTA used on premium surfaces like the
/// paywall. Kept separate from [AnimatedFrostyButton] so its restyle
/// doesn't ripple into the dashboard/coaching screens that also use that
/// widget.
class GradientPillButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  const GradientPillButton({
    super.key,
    required this.text,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: isDisabled ? null : OrbitTokens.signal,
          color: isDisabled ? OrbitTokens.surface2 : null,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: OrbitTokens.violet.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: OrbitTokens.ground,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    color: isDisabled ? OrbitTokens.inkFaint : OrbitTokens.ground,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
        ),
      ),
    );
  }
}
