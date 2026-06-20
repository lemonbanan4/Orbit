import 'package:flutter/material.dart';

class OrbitColors extends ThemeExtension<OrbitColors> {
  final Color orbColor1;
  final Color orbColor2;

  const OrbitColors({
    required this.orbColor1,
    required this.orbColor2,
  });

  @override
  ThemeExtension<OrbitColors> copyWith({
    Color? orbColor1,
    Color? orbColor2,
  }) {
    return OrbitColors(
      orbColor1: orbColor1 ?? this.orbColor1,
      orbColor2: orbColor2 ?? this.orbColor2,
    );
  }

  @override
  ThemeExtension<OrbitColors> lerp(
    ThemeExtension<OrbitColors>? other,
    double t,
  ) {
    if (other is! OrbitColors) return this;
    return OrbitColors(
      orbColor1: Color.lerp(orbColor1, other.orbColor1, t)!,
      orbColor2: Color.lerp(orbColor2, other.orbColor2, t)!,
    );
  }
}
