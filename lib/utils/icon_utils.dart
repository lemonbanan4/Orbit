import 'package:flutter/material.dart';

/// A centralized list of supported icons.
/// Keeping them explicitly defined as const here prevents tree-shaking errors
/// when building Flutter release bundles.
const List<IconData> supportedIcons = [
  Icons.star_rounded,
  Icons.fitness_center_rounded,
  Icons.self_improvement_rounded,
  Icons.water_drop_rounded,
  Icons.menu_book_rounded,
  Icons.directions_run_rounded,
  Icons.nightlight_round,
  Icons.wb_sunny_rounded,
  Icons.center_focus_strong_rounded,
  Icons.spa_rounded,
  Icons.local_fire_department_rounded,
];

IconData getIconFromCodePoint(int codePoint) {
  for (final icon in supportedIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.star_rounded; // Fallback icon
}
