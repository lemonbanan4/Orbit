// lib/screens/coaching/pro_coaching_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/orbit_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/ai_coach_service.dart';

class ProCoachingScreen extends StatefulWidget {
  const ProCoachingScreen({super.key});

  @override
  State<ProCoachingScreen> createState() => _ProCoachingScreenState();
}

class _ProCoachingScreenState extends State<ProCoachingScreen> {
  bool _isScanning = false;
  String _scanResult = "";
  // _isScanning only blocks *concurrent* taps -- nothing stopped mashing
  // the scan button back-to-back once each call finished, each one a
  // real Gemini call.
  DateTime? _lastScanAt;
  static const _scanCooldown = Duration(seconds: 10);

  void _runAlignmentScan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    if (_lastScanAt != null && now.difference(_lastScanAt!) < _scanCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give the telemetry a moment before scanning again.'),
        ),
      );
      return;
    }
    _lastScanAt = now;

    setState(() {
      _isScanning = true;
      _scanResult = "";
    });
    HapticFeedback.heavyImpact();

    try {
      // Pull live habits from database to analyze
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('habits')
          .get();

      final List<Map<String, dynamic>> habits = snapshot.docs
          .map((doc) => doc.data())
          .toList();

      if (habits.isEmpty) {
        setState(() {
          _scanResult =
              "🛸 Mission Control Alert: You must construct at least one habit constellation before running a telemetry alignment scan!";
          _isScanning = false;
        });
        return;
      }

      final result = await AiCoachService.generateProAlignmentScan(habits);

      setState(() {
        _scanResult = result;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _scanResult =
            "Cosmic interference detected. Retrying telemetry baseline link...";
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitTokens.ground,
      body: Stack(
        children: [
          // 🚀 THE BLUE BACKGROUND SHADE: Mimicking the exact radial glow from the image
          Positioned(
            bottom: -150,
            left: MediaQuery.of(context).size.width * 0.1,
            right: MediaQuery.of(context).size.width * 0.1,
            child: Container(
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                backgroundBlendMode: BlendMode.screen,
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFF0D1B3E,
                    ).withValues(alpha: 0.8), // Dark glowing cosmic indigo
                    const Color(
                      0xFF044B7F,
                    ).withValues(alpha: 0.4), // Radiant web blue accent
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  Expanded(child: Center(child: _buildGlassConsole())),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "COGNITIVE TELEMETRY",
              style: TextStyle(
                color: OrbitTokens.teal,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Mission Commander",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.white70,
            size: 32,
          ),
          padding: EdgeInsets.zero,
          alignment: Alignment.topRight,
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildGlassConsole() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
        ), // Premium Glassmorphism blurring
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.03,
            ), // Ultra faint highlight overlay
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.08,
              ), // Soft specular reflection edge
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scanner Node Icon
              Container(
                    // FIX: Put the key on the widget itself, not on the animate() extension
                    key: ValueKey(_isScanning),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: OrbitTokens.teal.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: OrbitTokens.teal.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      _isScanning ? Icons.sync_rounded : Icons.radar_rounded,
                      color: OrbitTokens.teal,
                      size: 32,
                    ),
                  )
                  .animate(
                    onPlay: (controller) =>
                        _isScanning ? controller.repeat() : null,
                  )
                  .rotate(duration: 2.seconds),

              const SizedBox(height: 24),
              const Text(
                "Stellar Alignment Scan",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Dynamic Response Box
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  alignment: Alignment.center,
                  child: _isScanning
                      ? Text(
                          "Pinging active satellites... Analyzing trajectory vectors...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Text(
                          _scanResult.isEmpty
                              ? "Initiate a complete spatial diagnostics pass across your current habit execution data matrices."
                              : _scanResult,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // Glass Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: OrbitTokens.teal.withValues(alpha: 0.4),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isScanning ? null : _runAlignmentScan,
                  child: const Text(
                    "INITIALIZE SCAN",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
