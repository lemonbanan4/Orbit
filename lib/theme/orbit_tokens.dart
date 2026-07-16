import 'package:flutter/material.dart';

/// The disciplined color system for Orbit's premium surfaces (paywall,
/// upsell dialogs): six tokens, each with one job, instead of picking a new
/// gradient per screen. See the redesign pitch for the rationale.
///
/// This is deliberately a fixed dark palette rather than a light/dark pair —
/// the paywall has always rendered as a dark, video-backed surface
/// regardless of the app's theme setting, and that stays true here.
class OrbitTokens {
  OrbitTokens._();

  static const Color ground = Color(0xFF07040F);
  static const Color surface = Color(0xFF14102A);
  static const Color surface2 = Color(0xFF1B1638);
  static const Color hairline = Color(0x1AF1EDFB);

  static const Color ink = Color(0xFFF3F0FC);
  static const Color inkDim = Color(0xFF948FBE);
  static const Color inkFaint = Color(0xFF5D5885);

  static const Color teal = Color(0xFF33E6D8);
  static const Color violet = Color(0xFFA66CFF);
  static const Color gold = Color(0xFFF2C879);

  /// Warm identity accent for "morning"-flavored surfaces (routine
  /// category color-coding, feature-card art) — sits alongside teal/violet
  /// as the third hue in that limited set, not a fourth arbitrary color.
  static const Color morning = Color(0xFFFF8A4C);

  static const LinearGradient signal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [teal, violet],
  );
}
