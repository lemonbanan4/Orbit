import 'package:flutter/material.dart';

enum OrbitAura { dawn, nova, voidSpace, deepNebula }

class AtmosphereProvider extends ChangeNotifier {
  OrbitAura _currentAura = OrbitAura.voidSpace;

  OrbitAura get currentAura => _currentAura;

  // Theme Colors based on Aura
  Color get primaryGlow =>
      _currentAura == OrbitAura.nova ? Colors.amberAccent : Colors.purpleAccent;
  Color get accentColor => _currentAura == OrbitAura.dawn
      ? Colors.cyanAccent
      : Colors.deepPurpleAccent;

  // Method for the AI Fairy to "Cast a Spell" and change the vibe
  void setAura(OrbitAura newAura) {
    _currentAura = newAura;
    notifyListeners();
  }

  /// Picks the aura Cosmica "casts" when a habit is completed — the same
  /// streak/skippedCount context already passed to
  /// AIFairyProvider.cheerForHabit() at every call site.
  static OrbitAura auraForHabitCompletion({
    required int streak,
    required int skippedCount,
  }) {
    if (skippedCount > 0) return OrbitAura.deepNebula; // bouncing back
    if (streak >= 7) return OrbitAura.nova; // on a roll
    if (streak <= 1) return OrbitAura.dawn; // fresh start
    return OrbitAura.voidSpace; // steady
  }
}
