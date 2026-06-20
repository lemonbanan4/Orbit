import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';

class AIFairyBubble extends StatefulWidget {
  final String message;
  final bool isListening;
  const AIFairyBubble({
    super.key,
    required this.message,
    this.isListening = false,
  });

  @override
  State<AIFairyBubble> createState() => _AIFairyBubbleState();
}

class _AIFairyBubbleState extends State<AIFairyBubble> {
  bool _isSpeaking = true;
  Timer? _speakingTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(AIFairyBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      setState(() => _isSpeaking = true);
      _startTimer();
    }
  }

  void _startTimer() {
    _speakingTimer?.cancel();
    // Estimate speaking time: ~50ms per character, bounded between 2-6 seconds
    final durationMs = (widget.message.length * 50).clamp(2000, 6000);
    _speakingTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _speakingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bubble = Container(
      padding: const EdgeInsets.all(2), // Width of the gradient border
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: widget.isListening
            ? const LinearGradient(
                colors: [Colors.cyanAccent, Colors.purpleAccent, Colors.amber],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: widget.isListening
            ? null
            : Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: widget.isListening
                ? Colors.cyanAccent.withValues(alpha: 0.4)
                : Colors.purple.withValues(alpha: 0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.cyanAccent,
                  size: 12,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Cosmica',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                FairyVoiceWave(isSpeaking: _isSpeaking),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isListening) {
      bubble = bubble
          .animate(onPlay: (c) => c.loop(reverse: true))
          .shimmer(duration: 1500.ms, color: Colors.white24)
          .scaleXY(begin: 1.0, end: 1.02, duration: 1.seconds);
    }

    return bubble
        .animate()
        .fade(duration: 500.ms)
        .slideY(begin: 0.2, end: 0)
        .shimmer(delay: 1.seconds, duration: 2.seconds);
  }
}

class FairyVoiceWave extends StatelessWidget {
  final bool isSpeaking;

  const FairyVoiceWave({super.key, this.isSpeaking = true});

  @override
  Widget build(BuildContext context) {
    if (!isSpeaking) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) =>
            Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
                .animate(onPlay: (c) => c.loop(reverse: true))
                .scaleY(
                  begin: 0.3,
                  end: 1.2,
                  // Stagger the animation so they pulse at different rates!
                  duration: (150 + index * 80).ms,
                  curve: Curves.easeInOutSine,
                ),
      ),
    );
  }
}
