/// The canonical focus-interest options, shared by the onboarding survey
/// and Settings' interests editor. Every entry maps to a wisdom_library
/// doc via sanctuary_screen.dart's _pickWisdomCategory (lowercase,
/// ' & ' -> '_', spaces -> '_', hyphens kept), and the joined list feeds
/// the AI coach's focus areas — keep the three in sync when adding one.
const List<String> interestOptions = [
  'Stoicism',
  'Emotional Wellness',
  'Pet Lovers',
  'Structure & Organisation',
  'Reading & Studying',
  'The Environment',
  'Mindful Eating',
  'Self-discipline',
  'Behavior Change',
  'Gratitude',
  'Creativity',
  'Aging',
  'Financial Habits',
  'Self-love',
  'Parenthood',
  'Productivity',
  'Better Relationships',
  'Mindfulness',
  'Physical Wellness',
  'Anxiety & Stress',
  'Detox Bad Habits',
  'Purpose & Motivation',
  'Better Sleep',
  'Balanced Life',
];
