// lib/widgets/sanctuary/wisdom_scroll_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../../screens/paywall/paywall_screen.dart';

class WisdomScrollOverlay extends StatefulWidget {
  final String category;
  final String content;
  final bool isPro;

  const WisdomScrollOverlay({
    super.key,
    required this.category,
    required this.content,
    required this.isPro,
  });

  @override
  State<WisdomScrollOverlay> createState() => _WisdomScrollOverlayState();
}

class _WisdomScrollOverlayState extends State<WisdomScrollOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color laserCyan = Color(0xFF00E5FF);
    Color glassText = Colors.white.withValues(alpha: 0.8);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.black.withValues(alpha: 0.1)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: AspectRatio(
                aspectRatio: 0.7,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: laserCyan.withValues(alpha: 0.08),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // KINETIC LASER SCANNING SWEEP (Tone alpha down if too "disco")
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _scannerController,
                          builder: (context, child) {
                            return FractionalTranslation(
                              translation: Offset(
                                0,
                                _scannerController.value * 2.0 - 1.0,
                              ),
                              child: child,
                            );
                          },
                          child: Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  laserCyan.withValues(alpha: 0.0),
                                  laserCyan.withValues(
                                    alpha: 0.05,
                                  ), // Kept subtle and low-profile
                                  laserCyan.withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // MASTER LAYOUT MATRIX CONTAINER
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 24,
                              left: 24,
                              right: 24,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "WISDOM_DATA://".toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                                Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: laserCyan,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .fade(duration: 800.ms),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.category.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(height: 2, width: 20, color: laserCyan),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: laserCyan.withValues(alpha: 0.2),
                                ),
                              ),
                              Container(height: 2, width: 20, color: laserCyan),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // SCROLLABLE TEXT PORT FRAME
                          Expanded(
                            child: Stack(
                              children: [
                                ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: const [
                                        Colors.black,
                                        Colors.black,
                                        Colors.transparent,
                                      ],
                                      stops: [
                                        0.0,
                                        widget.isPro ? 0.95 : 0.3,
                                        1.0,
                                      ], // Fade text much earlier for free tier
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: SingleChildScrollView(
                                    // 🚀 FIXED: Hard-locks scrolling mechanics instantly for free users
                                    physics: widget.isPro
                                        ? const BouncingScrollPhysics()
                                        : const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 120.0,
                                      ),
                                      child: Text(
                                        widget.content,
                                        style: TextStyle(
                                          color: glassText,
                                          fontSize: 15,
                                          fontFamily: 'Courier',
                                          height: 1.5,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // 🚀 FIXED: Frosted Paywall Blocker Sheet
                                if (!widget.isPro)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    top:
                                        100, // Forces the paywall card container upwards into line 3-4 airspace
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(16),
                                      ),
                                      child: BackdropFilter(
                                        // Dynamic glass refraction blurs out reading tracking paths behind card boundary
                                        filter: ImageFilter.blur(
                                          sigmaX: 12,
                                          sigmaY: 12,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 20,
                                          ),
                                          decoration: BoxDecoration(
                                            // Soft darkening layer adds legibility to button items over text lines
                                            color: Colors.black.withValues(
                                              alpha: 0.65,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.lock_rounded,
                                                color: laserCyan,
                                                size: 32,
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                "DEEP WISDOM LOCKED",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                "Upgrade your alignment vectors to read this full transmission.",
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              Container(
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF6B1DFF,
                                                      ).withValues(alpha: 0.4),
                                                      blurRadius: 20,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF6B1DFF),
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    HapticFeedback.lightImpact();
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            const PaywallScreen(),
                                                      ),
                                                    );
                                                  },
                                                  child: const Text(
                                                    "UNLOCK DEEP ALIGNMENT WITH PRO",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      letterSpacing: 1.0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fade(duration: 500.ms).scaleY(begin: 0, end: 1, duration: 800.ms, curve: Curves.easeOutBack).shimmer(delay: 1200.ms, color: Colors.white24, duration: 1200.ms),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
