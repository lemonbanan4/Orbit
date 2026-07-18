// lib/providers/telemetry_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelemetryProvider extends ChangeNotifier {
  int _globalXp = 0;
  int _currentLevel = 1;
  bool _isDataLoaded = false;

  int get globalXp => _globalXp;
  int get currentLevel => _currentLevel;
  bool get isDataLoaded => _isDataLoaded;

  // XP threshold calculation: Each level requires sequentially more energy
  int get xpForNextLevel => _currentLevel * 150;
  double get levelProgressFraction => _globalXp / xpForNextLevel;

  List<int> _unlockedMilestones = [];
  List<int> get unlockedMilestones => _unlockedMilestones;

  TelemetryProvider() {
    _loadStateFromDisk();
  }

  Future<void> _loadStateFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    _globalXp = prefs.getInt('global_xp') ?? 0;
    _currentLevel = prefs.getInt('current_level') ?? 1;

    final savedMilestones = prefs.getStringList('unlocked_milestones') ?? [];
    _unlockedMilestones = savedMilestones.map((e) => int.parse(e)).toList();

    _isDataLoaded = true;
    notifyListeners();

    _loadFromCloud();
  }

  Future<void> _loadFromCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));
      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('global_xp')) _globalXp = data['global_xp'];
        if (data.containsKey('current_level')) {
          _currentLevel = data['current_level'];
        }
        if (data.containsKey('unlocked_milestones')) {
          _unlockedMilestones = List<int>.from(data['unlocked_milestones']);
        }
        notifyListeners();
        _saveLocal();
      }
    } catch (e) {
      debugPrint("Failed to load telemetry from cloud: $e");
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('global_xp', _globalXp);
    await prefs.setInt('current_level', _currentLevel);
    await prefs.setStringList(
      'unlocked_milestones',
      _unlockedMilestones.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _saveToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'global_xp': _globalXp,
        'current_level': _currentLevel,
        'unlocked_milestones': _unlockedMilestones,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Failed to save telemetry to cloud: $e");
    }
  }

  /// Adds XP dynamically and checks for Rank Level-Up metrics shifts
  Future<bool> awardXp(int amount) async {
    _globalXp += amount;
    bool leveledUp = false;

    // Check if user breaks past current level cap threshold
    while (_globalXp >= xpForNextLevel) {
      _globalXp -= xpForNextLevel;
      _currentLevel++;
      leveledUp = true;
    }

    await _saveLocal();
    _saveToCloud();

    notifyListeners();
    return leveledUp; // Returns true to trigger popups natively
  }

  // --- AUTO-UNLOCK MILESTONES ---
  List<int> checkMilestoneUnlocks(int currentStreak) {
    final streakThresholds = [
      3,
      7,
      14,
      21,
      30,
      45,
      60,
      90,
      120,
      150,
      180,
      210,
      250,
      300,
      365,
    ];

    List<int> newlyUnlocked = [];
    bool didUnlock = false;

    for (int i = 0; i < streakThresholds.length; i++) {
      if ((currentStreak >= streakThresholds[i]) &&
          !_unlockedMilestones.contains(i)) {
        _unlockedMilestones.add(i);
        newlyUnlocked.add(i);
        didUnlock = true;
      }
    }

    if (didUnlock) {
      notifyListeners();
      _saveLocal();
      _saveToCloud();
    }

    return newlyUnlocked; // Return the IDs so the UI can show a Toast!
  }
}
