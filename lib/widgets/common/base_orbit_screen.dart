import 'package:flutter/material.dart';
import 'glow_orb.dart';
import '../../theme/orbit_colors.dart';

class BaseOrbitScreen extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  const BaseOrbitScreen({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    // Dynamic Orb Colors from ThemeExtension
    final orbitColors = theme.extension<OrbitColors>();
    final orbColor1 = orbitColors?.orbColor1.withValues(alpha: 0.2) ??
        const Color(0x3300E5FF);
    final orbColor2 = orbitColors?.orbColor2.withValues(alpha: 0.2) ??
        const Color(0x337000FF);

    return Scaffold(
      // Uses the background color from main.dart's ThemeData automatically!
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: actions,
        bottom: bottom,
      ),
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          // Global Glow Orbs - Write this ONCE, not in every file!
          GlowOrb(color: orbColor1, size: 300, top: -100, right: -50),
          GlowOrb(color: orbColor2, size: 350, bottom: -50, left: -100),
          SafeArea(child: body),
        ],
      ),
    );
  }
}
