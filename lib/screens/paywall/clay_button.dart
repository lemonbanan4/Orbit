import 'package:flutter/material.dart';

class ClayButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const ClayButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF), // Your brand's cyan color
          borderRadius: BorderRadius.circular(24),
          boxShadow: _isPressed
              ? [] // No shadow when pressed
              : [
                  // Bottom-right shadow (darker)
                  const BoxShadow(
                    color: Color(0xFF00AABF), // Darker shade of cyan
                    offset: Offset(5, 5),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                  // Top-left highlight (lighter)
                  BoxShadow(
                    color: const Color(
                      0xFF61FFFF,
                    ).withValues(alpha: 0.8), // Lighter shade
                    offset: const Offset(-5, -5),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.black),
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
