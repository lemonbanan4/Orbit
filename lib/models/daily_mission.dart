import 'package:flutter/material.dart';

/// A daily mission — a small same-day goal that grants bonus XP when claimed.
/// Progress is measured against how many habits are completed *today*, which
/// resets automatically at the daily rollover (RoutineProvider._checkDailyReset),
/// so missions renew every day with no per-mission timestamps to manage.
class DailyMission {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Habits-completed-today required to complete this mission.
  final int target;

  /// XP granted once, when the player claims a completed mission.
  final int rewardXp;

  const DailyMission({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
    required this.rewardXp,
  });
}

/// The three daily missions, escalating in effort and reward. All measure the
/// same "habits completed today" signal, so there is no XP-from-rewards feedback
/// loop (rewards never count toward mission progress).
const List<DailyMission> kDailyMissions = [
  DailyMission(
    id: 'first_light',
    title: 'First Light',
    description: 'Complete 1 habit today',
    icon: Icons.wb_twilight_rounded,
    target: 1,
    rewardXp: 15,
  ),
  DailyMission(
    id: 'momentum',
    title: 'Finding Momentum',
    description: 'Complete 3 habits today',
    icon: Icons.bolt_rounded,
    target: 3,
    rewardXp: 25,
  ),
  DailyMission(
    id: 'full_orbit',
    title: 'Full Orbit',
    description: 'Complete 5 habits today',
    icon: Icons.brightness_7_rounded,
    target: 5,
    rewardXp: 40,
  ),
];
