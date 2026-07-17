import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// A dot orbiting a faint ring, replacing the platform's default spinner
/// inside [CupertinoSliverRefreshControl]. Rotation tracks pull distance
/// while dragging so the gesture feels connected to the visual, then spins
/// continuously once the actual refresh is running.
class OrbitalRefreshIndicator extends StatefulWidget {
  final RefreshIndicatorMode refreshState;
  final double pulledExtent;
  final double triggerDistance;
  final Color accent;

  const OrbitalRefreshIndicator({
    super.key,
    required this.refreshState,
    required this.pulledExtent,
    required this.triggerDistance,
    required this.accent,
  });

  @override
  State<OrbitalRefreshIndicator> createState() =>
      _OrbitalRefreshIndicatorState();
}

class _OrbitalRefreshIndicatorState extends State<OrbitalRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  bool get _isSpinning =>
      widget.refreshState == RefreshIndicatorMode.refresh ||
      widget.refreshState == RefreshIndicatorMode.armed;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (_isSpinning) _spinController.repeat();
  }

  @override
  void didUpdateWidget(covariant OrbitalRefreshIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isSpinning && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!_isSpinning && _spinController.isAnimating) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress = widget.triggerDistance <= 0
        ? 0.0
        : (widget.pulledExtent / widget.triggerDistance).clamp(0.0, 1.0);

    return SizedBox(
      height: 64,
      child: Center(
        child: Opacity(
          opacity: dragProgress,
          child: AnimatedBuilder(
            animation: _spinController,
            builder: (context, child) {
              final angle = _isSpinning
                  ? _spinController.value * 2 * math.pi
                  : dragProgress * 2 * math.pi;
              return Transform.rotate(angle: angle, child: child);
            },
            child: SizedBox(
              width: 28,
              height: 28,
              child: CustomPaint(
                painter: _OrbitDotPainter(color: widget.accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitDotPainter extends CustomPainter {
  final Color color;
  _OrbitDotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.25),
    );

    final dotCenter = center.translate(0, -radius);
    canvas.drawCircle(
      dotCenter,
      4.5,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(dotCenter, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _OrbitDotPainter oldDelegate) =>
      oldDelegate.color != color;
}
