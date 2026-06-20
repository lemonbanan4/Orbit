import 'dart:ui';
import 'package:flutter/material.dart';

class PremiumGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool isPro;
  final Gradient? gradient;

  const PremiumGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.isPro = false,
    this.gradient,
  });

  @override
  State<PremiumGlassCard> createState() => _PremiumGlassCardState();
}

class _PremiumGlassCardState extends State<PremiumGlassCard> {
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // RepaintBoundary gives BackdropFilter its own compositing layer with
    // fixed pixel bounds. Without it, when PremiumGlassCard is placed inside
    // a SliverList, the BackdropFilter inherits the sliver's remainingPaintExtent
    // which can go below the card's minimum height during BouncingScrollPhysics
    // overscroll — triggering "BoxConstraints has a negative minimum height".
    return RepaintBoundary(
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // Adjust sensitivity of the tilt
            _tiltX += details.delta.dy * -0.01;
            _tiltY += details.delta.dx * 0.01;

            // Clamp the rotation so it doesn't flip entirely
            _tiltX = _tiltX.clamp(-0.15, 0.15);
            _tiltY = _tiltY.clamp(-0.15, 0.15);
          });
        },
        onPanEnd: (_) => _resetTilt(),
        onPanCancel: _resetTilt,
        child: TweenAnimationBuilder(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          tween: Tween<Offset>(begin: Offset.zero, end: Offset(_tiltX, _tiltY)),
          builder: (context, Offset tilt, child) {
            final matrix = Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateX(tilt.dx)
              ..rotateY(tilt.dy);

            return Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: Stack(
                children: [
                  child!, // The cached glass card UI
                  // The Shiny Glare Overlay!
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          // border: Border.all(
                          //   color: Colors.white.withOpacity(0.15),
                          //),
                          gradient:
                              widget.gradient ??
                              RadialGradient(
                                // Move the glare opposite to the tilt direction
                                center: Alignment(-tilt.dy * 8, -tilt.dx * 8),
                                radius: 1.2,
                                colors: [
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.6],
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: widget.isPro
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.12),
                    width: widget.isPro ? 2.0 : 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isPro
                        ? [
                            const Color(0xFF00E5FF).withValues(alpha: 0.2),
                            const Color(0xFF7000FF).withValues(alpha: 0.1),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ), // closes GestureDetector
    ); // closes RepaintBoundary
  }

  void _resetTilt() {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }
}
