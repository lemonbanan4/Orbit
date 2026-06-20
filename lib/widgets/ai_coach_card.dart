import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';

class AICoachCard extends StatefulWidget {
  final String fairyMessage;
  final VoidCallback onRefresh;
  final bool isLoading; // Add loading state

  const AICoachCard({
    super.key,
    required this.fairyMessage,
    required this.onRefresh,
    this.isLoading = false,
  });

  @override
  State<AICoachCard> createState() => _AICoachCardState();
}

class _AICoachCardState extends State<AICoachCard> {
  // 3D Matrix manipulation values based on pointer location
  double _localX = 0;
  double _localY = 0;
  bool _defaultPosition = true;

  @override
  Widget build(BuildContext context) {
    // --- 3D INTERACTIVE SENSING ---
    // When the user moves their finger over the card, it rotates in 3D
    return MouseRegion(
      onEnter: (_) => setState(() => _defaultPosition = false),
      onExit: (_) => setState(() => _defaultPosition = true),
      onHover: (details) {
        if (_defaultPosition) return;
        setState(() {
          _localX = details.localPosition.dx - (details.size / 2);
          _localY = details.localPosition.dy - (details.size / 2);
        });
      },
      child: AnimatedRotation(
        duration: 300.ms,
        curve: Curves.easeOutCubic,
        turns: _defaultPosition ? 0 : (_localX * 0.0001), // Slgiht turn on X
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF9D4EDD).withValues(alpha: 0.2), // Purple
                    const Color(0xFF00B4D8).withValues(alpha: 0.05), // Cyan
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- THE UPGRADED 3D GLASSY FAIRY ---
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ambient Backglow
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00B4D8)
                                  .withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      // The AI Generated 3D Asset
                      Image.asset(
                        'assets/images/fairy_avatar.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          // Subtle infinite float to look "live 3D"
                          .moveY(
                              begin: -4,
                              end: 4,
                              duration: 2.seconds,
                              curve: Curves.easeInOut),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // The AI Message
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "COSMIC GUIDE",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            // Refresh button or Loading indicator
                            widget.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF00B4D8),
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: widget.onRefresh,
                                    child: const Icon(
                                      Icons.refresh,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.fairyMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        )
                            .animate(key: Key(widget.fairyMessage))
                            // Fade in the text every time it changes
                            .fadeIn(duration: 500.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
