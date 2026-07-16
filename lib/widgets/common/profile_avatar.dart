import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/orbit_colors.dart';

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
    final orbitColors = Theme.of(context).extension<OrbitColors>();
    final Color accent1 = orbitColors?.orbColor1 ?? const Color(0xFF00E5FF);
    final Color accent2 = orbitColors?.orbColor2 ?? const Color(0xFF7000FF);

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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [accent1, accent2, Colors.amber, accent1],
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
                  ? Icon(Icons.person_rounded, size: 48, color: accent1)
                  : null,
            ),
            if (isUploading)
              Positioned.fill(
                  child: CircularProgressIndicator(color: accent1)),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13002B),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent1, width: 2),
                ),
                child: Icon(Icons.camera_alt_rounded,
                    color: accent1, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
