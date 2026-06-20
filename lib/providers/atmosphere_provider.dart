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
}
