import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../paywall/paywall_screen.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/floating_particles.dart';
import '../../theme/orbit_tokens.dart';

class ContractScreen extends StatefulWidget {
  final String userName;

  const ContractScreen({super.key, required this.userName});

  @override
  State<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends State<ContractScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bgScaleAnimation;
  bool _isComplete = false;
  late ConfettiController _confettiController;
  bool _isFadingOut = false;

  @override
  void initState() {
    super.initState();
    // 2.5 seconds to fill the contract ring
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 15.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    // The background zooms in by 15% as they hold the button!
    _bgScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutSine));

    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1500),
    );

    _controller.addListener(() {
      setState(() {});
      if (_controller.value > 0.1 && _controller.value < 0.9) {
        HapticFeedback.selectionClick(); // Satisfying clicks while holding
      }
      if (_controller.isCompleted && !_isComplete) {
        _isComplete = true;
        HapticFeedback.heavyImpact();

        _confettiController.play(); // Fire the sparks!

        // Start fading the screen out after 500ms
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _isFadingOut = true);
        });

        // Delay the navigation slightly so they can enjoy the explosion!
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const PaywallScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) =>
                        FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 800),
              ),
            );
          }
        });
      }
    });
  }

  void _onPressDown(TapDownDetails details) {
    if (!_isComplete) _controller.forward();
  }

  void _onPressUp(TapUpDetails details) {
    if (!_isComplete) _controller.reverse(); // Shrink back if they let go!
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String name = widget.userName.isNotEmpty ? widget.userName : 'Commander';

    return Scaffold(
      backgroundColor: Colors.black, // Ensures the background fades to black
      body: AnimatedOpacity(
        opacity: _isFadingOut ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. The Zooming Background Image
            AnimatedBuilder(
              animation: _bgScaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bgScaleAnimation.value,
                  child: Image.asset(
                    'assets/images/contract_bg.png',
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),

            // 2. The Dark Blue Overlay (Keeps text readable!)
            Container(color: OrbitTokens.surface.withValues(alpha: 0.85)),

            // 3. The Floating Space Dust Overlay
            const FloatingParticles().animate().fade(duration: 2.seconds),

            // 4. The Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Text(
                          "$name's Contract",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        .animate()
                        .fade(duration: 600.ms)
                        .shimmer(
                          duration: 1500.ms,
                          delay: 600.ms,
                          color: Colors.white54,
                        ),
                    const SizedBox(height: 16),
                    Text(
                          "I, $name, will make the most of tomorrow. I will always remember that I will not live forever. Every fear and irritation that threatens to distract me will become fuel for building my best life one day at a time.",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                        .animate()
                        .fade(duration: 600.ms, delay: 200.ms)
                        .shimmer(
                          duration: 1500.ms,
                          delay: 800.ms,
                          color: Colors.white54,
                        ),
                    const Spacer(),
                    const Center(
                      child: Text(
                        "Hint: tap and hold to commit.\nPrecommitting to a goal has been shown to inspire action and reduce procrastination.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // THE HOLD-TO-COMMIT BUTTON
                    Center(
                      child: GestureDetector(
                        onTapDown: _onPressDown,
                        onTapUp: _onPressUp,
                        onTapCancel: () => _controller.reverse(),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // The growing rings
                            Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: OrbitTokens.gold.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: _scaleAnimation.value * 0.8,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: OrbitTokens.gold.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ),
                            // The solid center
                            Container(
                                  width: 100,
                                  height: 100,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: OrbitTokens.gold,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _controller.isAnimating
                                          ? "Almost there"
                                          : "Hold",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scaleXY(
                                  begin: 1.0,
                                  end: 1.05,
                                  duration: 1200.ms,
                                  curve: Curves.easeInOut,
                                ),
                            // The Sparks!
                            // IgnorePointer: an unconstrained ConfettiWidget
                            // expands to fill all available space and stays
                            // hit-testable even when idle, which would
                            // otherwise balloon this GestureDetector's
                            // effective tap target well beyond the visible
                            // hold-to-commit circle.
                            IgnorePointer(
                              child: ConfettiWidget(
                                confettiController: _confettiController,
                                blastDirectionality: BlastDirectionality
                                    .explosive, // Blasts in all directions
                                // CUSTOM ICE SHARDS
                                createParticlePath: drawIceShard,
                                colors: const [
                                  Colors.white,
                                  Colors.lightBlueAccent,
                                  Color(0xFF81D4FA),
                                  Colors.cyanAccent,
                                ],
                                gravity:
                                    0.2, // Make them fall a bit slower, like shards
                                emissionFrequency: 0.05,
                                numberOfParticles: 30,

                                // emissionFrequency: 0.05,
                                // numberOfParticles: 30,
                                // gravity: 0.3,
                                // colors: const [Color(0xFFFFD600), Colors.white, Color(0xFF00E5FF)], // Theme colors!
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// CUSTOM ICE SHARDS
// Draws a sharp, elongated diamond/shard shape
Path drawIceShard(Size size) {
  final path = Path();
  path.moveTo(size.width / 2, 0); // Sharp top point
  path.lineTo(size.width, size.height * 0.3); // Right edge (higher up)
  path.lineTo(size.width / 2, size.height); // Long sharp bottom point
  path.lineTo(0, size.height * 0.3); // Left edge
  path.close();
  return path;
}
