import 'package:flutter/material.dart';
import 'package:orbit_app/services/ai_fairy_service.dart';
import 'package:orbit_app/services/voice_service.dart';
import 'package:audioplayers/audioplayers.dart';

class AIFairyProvider extends ChangeNotifier {
  final AIFairyService _service = AIFairyService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _currentMessage = "Welcome back, Star-seeker!";
  List<String> _suggestedReplies = ["Let's go!", "I'm ready", "Guide me"];
  bool _isCheering = false; // Renamed from _isVisible
  bool _isThinking = false;
  String?
  _activeHabitName; // New field to store the habit name that triggered the fairy

  String get currentMessage => _currentMessage;
  List<String> get suggestedReplies => _suggestedReplies;
  bool get isCheering => _isCheering; // Renamed getter
  bool get isThinking => _isThinking;
  String? get activeHabitName => _activeHabitName; // New getter

  // This is the "Magic Trigger" called when a habit is completed
  Future<void> cheerForHabit(
    String habitName,
    int streak, {
    bool playSound = true,
    int skippedCount = 0,
  }) async {
    _isCheering = true; // Set to true when cheering starts
    _activeHabitName = habitName; // Store the habit name
    _isThinking = true;
    notifyListeners();

    if (playSound) {
      try {
        await _audioPlayer.play(AssetSource('audio/fairy_pop.mp3'));
      } catch (e) {
        debugPrint('Failed to play fairy sound: $e');
      }
    }

    try {
      // We use the JSON interaction we built earlier
      final response = await _service.getFairyInteraction(
        habitName,
        skippedCount: skippedCount,
      );

      _currentMessage = response.text;
      _suggestedReplies = response.options;
    } catch (e) {
      _currentMessage =
          "You're glowing! That $streak-day streak is legendary! ✨";
      _suggestedReplies = ["Heck yes!", "Keep it up"];
    } finally {
      _isThinking = false;
      notifyListeners();
    }
  }

  void dismissFairy() {
    _isCheering = false; // Set to false when fairy is dismissed
    _activeHabitName = null; // Clear the active habit name
    // If the user tapped the fairy to hear her message spoken (TTS via
    // VoiceService.speak in ai_fairy_overlay), dismissing her should also
    // silence her — previously the speech just kept playing over whatever
    // the user did next.
    VoiceService.stop();
    notifyListeners();
  }
}
