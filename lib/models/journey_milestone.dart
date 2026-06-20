class JourneyMilestone {
  final String id; // To track progress in Firebase
  final String title;
  final String description; // The "Quest" text
  final String iconPath;
  final bool isCompleted;
  final bool isLocked; // For the "Not yet unlocked" states in your images
  final int requiredStreak; // e.g., "Need 7 days to unlock this"
  final String fairyEncouragement; // The specific AI Fairy line for this step

  JourneyMilestone({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    this.isCompleted = false,
    this.isLocked = true,
    this.requiredStreak = 0,
    required this.fairyEncouragement,
  });
}
