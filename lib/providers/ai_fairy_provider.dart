import 'package:flutter/material.dart';
import 'package:orbit_app/services/ai_fairy_service.dart';
import 'package:orbit_app/services/voice_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AIFairyProvider extends ChangeNotifier {
  final AIFairyService _service = AIFairyService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _currentMessage = "Welcome back, Star-seeker!";
  List<String> _suggestedReplies = ["Let's go!", "I'm ready", "Guide me"];
  bool _isCheering = false; // Renamed from _isVisible
  bool _isThinking = false;
  String?
  _activeHabitName; // New field to store the habit name that triggered the fairy
  // cheerForHabit fires a real Gemini call on every completed->incomplete
  // ->completed transition, which a user can trigger indefinitely by
  // rapidly un/re-checking a habit -- nothing upstream debounces that.
  DateTime? _lastCheerAt;
  static const _cheerCooldown = Duration(seconds: 8);

  // Every habit completion fired a real Gemini call for every user with no
  // Pro gate or daily cap at all -- unbounded LLM spend with no revenue
  // offset, and it also removed any incentive to upgrade since the app's
  // flagship "AI coaching" touchpoint was already free everywhere. Free
  // accounts now get a small number of real fairy interactions per day;
  // Pro is unlimited. Persisted (not just in-memory) so a force-quit/reopen
  // can't reset the count within the same day.
  static const _freeDailyCheerCap = 5;
  static const _cheerCountPrefsKey = 'ai_fairy_cheer_count';
  static const _cheerCountDatePrefsKey = 'ai_fairy_cheer_count_date';

  Future<bool> _consumeFreeCheerAllowance() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(_cheerCountDatePrefsKey);
    final count = storedDate == todayKey
        ? (prefs.getInt(_cheerCountPrefsKey) ?? 0)
        : 0;
    if (count >= _freeDailyCheerCap) return false;
    await prefs.setString(_cheerCountDatePrefsKey, todayKey);
    await prefs.setInt(_cheerCountPrefsKey, count + 1);
    return true;
  }

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
    bool isPro = false,
  }) async {
    _isCheering = true; // Set to true when cheering starts
    _activeHabitName = habitName; // Store the habit name
    notifyListeners();

    if (playSound) {
      try {
        await _audioPlayer.play(AssetSource('audio/fairy_pop.mp3'));
      } catch (e) {
        debugPrint('Failed to play fairy sound: $e');
      }
    }

    // Rapidly un/re-checking a habit can trigger this repeatedly with no
    // gate upstream -- still celebrate (habit completion should always
    // feel rewarding), just skip the API call and use a canned line
    // instead of hitting Gemini on every bounce.
    final now = DateTime.now();
    if (_lastCheerAt != null && now.difference(_lastCheerAt!) < _cheerCooldown) {
      _currentMessage = "You're glowing! Keep that momentum going! ✨";
      _suggestedReplies = ["Heck yes!", "Keep it up"];
      _isThinking = false;
      notifyListeners();
      return;
    }
    _lastCheerAt = now;

    if (!isPro && !await _consumeFreeCheerAllowance()) {
      _currentMessage =
          "You're glowing! That $streak-day streak is legendary! ✨";
      _suggestedReplies = ["Heck yes!", "Keep it up"];
      _isThinking = false;
      notifyListeners();
      return;
    }

    _isThinking = true;
    notifyListeners();

    try {
      // We use the JSON interaction we built earlier
      final response = await _service.getFairyInteraction(
        habitName,
        skippedCount: skippedCount,
        streak: streak,
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

  /// Persists the tapped suggested-reply chip to fairy_history --
  /// AIFairyService.saveInteraction() was fully built (own Firestore rule,
  /// cleaned up on account deletion/migration) but had zero callers, so
  /// this entire chat-history feature never received a write.
  void recordReply(String userReply) {
    _service.saveInteraction(
      _activeHabitName ?? 'general',
      _currentMessage,
      userReply,
    );
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
