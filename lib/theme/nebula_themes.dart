import 'package:flutter/material.dart';
import 'orbit_tokens.dart';

/// A purchasable cosmetic accent pair applied app-wide via the
/// [OrbitColors] theme extension (see [main.dart]'s `darkTheme` build and
/// every `Theme.of(context).extension<OrbitColors>()` call site).
class NebulaTheme {
  final String name;
  final String description;
  final Color orbColor1;
  final Color orbColor2;

  /// XP cost to unlock. Zero means always unlocked (the default theme).
  final int cost;

  const NebulaTheme({
    required this.name,
    required this.description,
    required this.orbColor1,
    required this.orbColor2,
    this.cost = 0,
  });
}

class NebulaThemes {
  NebulaThemes._();

  static const int unlockCost = 500;

  static const List<NebulaTheme> all = [
    NebulaTheme(
      name: 'Default',
      description: 'The Orbit you know — solar orange meets deep violet.',
      orbColor1: Color(0xFFFF5F00),
      orbColor2: Color(0xFF7000FF),
    ),
    NebulaTheme(
      name: 'Aurora',
      description: 'Cool teal and violet, like the northern lights.',
      orbColor1: OrbitTokens.teal,
      orbColor2: OrbitTokens.violet,
      cost: unlockCost,
    ),
    NebulaTheme(
      name: 'Solstice',
      description: 'Warm gold and ember for a sunset-lit sky.',
      orbColor1: OrbitTokens.gold,
      orbColor2: OrbitTokens.morning,
      cost: unlockCost,
    ),
  ];

  static NebulaTheme byName(String name) =>
      all.firstWhere((t) => t.name == name, orElse: () => all.first);
}
