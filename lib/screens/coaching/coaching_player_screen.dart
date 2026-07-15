import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // We know this works now!

class CoachingPlayerScreen extends StatefulWidget {
  final String sessionTitle;
  final String imageUrl; // This is where we'll link your new Lighthouse image
  final String audioUrl;

  const CoachingPlayerScreen({
    super.key,
    required this.sessionTitle,
    required this.imageUrl,
    required this.audioUrl,
  });

  @override
  State<CoachingPlayerScreen> createState() => _CoachingPlayerScreenState();
}

class _CoachingPlayerScreenState extends State<CoachingPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    // Logic to initialize audio duration
  }

  @override
  void dispose() {
    _player.dispose(); // Important for memory!
    super.dispose();
  }

  // --- AUDIO LOGIC (Play/Pause/Seek) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050112), // Deep Orbit Void Color
      body: Stack(
        children: [
          // 1. YOUR NEW AI IMAGE: The "Lighthouse" Background
          // Once you generate it, put it in 'assets/images/lighthouse.png'
          Positioned.fill(
            child: Image.asset(
              'assets/images/lighthouse.png', // Fallback until you have the asset
              fit: BoxFit.cover,
            ),
          ),

          // 2. Gradient Overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    const Color(0xFF050112).withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),

          // 3. Player UI Content
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // --- HEADER: Title & Dismiss Button ---
                  // --- VOLUME SLIDER ---
                  Spacer(),
                  // --- PLAYER CONTROLS (Seekbar, Play/Pause) ---
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
