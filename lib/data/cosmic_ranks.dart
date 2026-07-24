/// Cosmic Ranks — gives Orbit's XP levels a felt progression instead of a bare
/// number. Purely derived from `currentLevel` (a pure function of XP), so this
/// adds no state, no persistence, and no economy changes: it can't drift from
/// the real level or affect existing data.
class CosmicRank {
  final String title;

  /// Lowest level (inclusive) that holds this rank.
  final int minLevel;

  const CosmicRank(this.title, this.minLevel);
}

/// The ladder, ascending by minLevel. Keep the first entry at level 1.
const List<CosmicRank> kCosmicRanks = [
  CosmicRank('Drifter', 1),
  CosmicRank('Stargazer', 3),
  CosmicRank('Voyager', 5),
  CosmicRank('Navigator', 8),
  CosmicRank('Commander', 12),
  CosmicRank('Captain', 17),
  CosmicRank('Admiral', 25),
  CosmicRank('Celestial', 40),
  CosmicRank('Cosmic Legend', 60),
];

/// The rank held at [level] (the highest rank whose minLevel <= level).
CosmicRank cosmicRankForLevel(int level) {
  CosmicRank current = kCosmicRanks.first;
  for (final rank in kCosmicRanks) {
    if (level >= rank.minLevel) {
      current = rank;
    } else {
      break;
    }
  }
  return current;
}

/// The next rank above [level], or null if already at the top rank.
CosmicRank? nextCosmicRank(int level) {
  for (final rank in kCosmicRanks) {
    if (rank.minLevel > level) return rank;
  }
  return null;
}
