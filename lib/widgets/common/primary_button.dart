import 'package:flutter/material.dart';
import '../../theme/orbit_colors.dart';

/// The app's primary call-to-action: a glowing gradient pill with a tactile
/// press-scale. The gradient and glow are derived from the *live* accent
/// (OrbitColors.orbColor1), so it stays on-brand across Nebula themes instead
/// of hard-coding one colour. Drop-in compatible with the old flat button --
/// same (text, onPressed, isLoading) API.
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);
    final bool disabled = widget.isLoading;
    // A brighter tint of the accent gives the gradient depth without leaving
    // the theme's colour family.
    final Color accentBright = Color.lerp(accent, Colors.white, 0.26)!;

    return GestureDetector(
      onTap: disabled ? null : widget.onPressed,
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentBright, accent],
                  ),
            color: disabled ? accent.withValues(alpha: 0.4) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: _pressed ? 0.25 : 0.45),
                      blurRadius: _pressed ? 12 : 22,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 3,
                  ),
                )
              : Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
