import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'contract_screen.dart';
import '../../theme/orbit_tokens.dart';
import '../../widgets/common/primary_button.dart';

class FutureLetterScreen extends StatefulWidget {
  final String userName;
  const FutureLetterScreen({super.key, required this.userName});

  @override
  State<FutureLetterScreen> createState() => _FutureLetterScreenState();
}

class _FutureLetterScreenState extends State<FutureLetterScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitTokens.ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'Dear ${widget.userName},',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Orbit. Your journey starts now. Master your habits, organize your life, and become the best version of yourself. We are thrilled to have you here.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  height: 1.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 800.ms)
                  .slideY(begin: 0.2),
              const Spacer(flex: 2),
              PrimaryButton(
                text: 'Begin Journey',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ContractScreen(userName: widget.userName),
                    ),
                  );
                },
              ).animate().fadeIn(delay: 1000.ms, duration: 800.ms),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
