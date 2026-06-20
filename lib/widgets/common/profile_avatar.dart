import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final bool isUploading;
  final VoidCallback onTap;

  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated Gradient Border
            Container(
              width: 106,
              height: 106,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFF00E5FF),
                    Color(0xFF7000FF),
                    Colors.amber,
                    Color(0xFF00E5FF),
                  ],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 3.seconds),
            // Inner background
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF13002B),
              ),
            ),
            // The User Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.transparent,
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl!) : null,
              child: photoUrl == null
                  ? const Icon(Icons.person_rounded,
                      size: 48, color: Color(0xFF00E5FF))
                  : null,
            ),
            if (isUploading)
              const Positioned.fill(
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13002B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFF00E5FF), size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
