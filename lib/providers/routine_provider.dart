import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';
import 'dart:convert';
import '../services/notification_service.dart';
import '../models/routine_alarm.dart';
import '../models/habit.dart';
import '../theme/nebula_themes.dart';
import '../utils/dev_overrides.dart';

class RoutineProvider extends ChangeNotifier with WidgetsBindingObserver {
  SharedPreferences? _prefs;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  StreamSubscription<User?>? _authSubscription;
  Timer? _midnightTimer;
  String? _previousUid;
  final audioplayers.AudioPlayer _audioPlayer;
  final ja.AudioPlayer _ambientPlayer;
  bool _isDisposed = false;

  bool _justLeveledUp = false;
  bool _lowPowerMode = false;

  String get _userId => _auth.currentUser?.uid ?? "commander_001";
  // Daily intentions
  String? _dailyIntention;
  String? get dailyIntention => _dailyIntention;
  Map<String, String> _intentionHistory = {};
  Map<String, String> get intentionHistory => _intentionHistory;

  bool _showIntentionPrompt = false;
  bool get showIntentionPrompt => _showIntentionPrompt;

  void triggerIntentionPrompt() {
    _showIntentionPrompt = true;
    notifyListeners();
  }

  void consumeIntentionPrompt() {
    _showIntentionPrompt = false;
  }

  // Custom Routine Rewards
  Map<String, String> _routineRewards = {};
  Map<String, String> get routineRewards => _routineRewards;

  String getRoutineReward(String routineType) =>
      _routineRewards[routineType] ?? '';
  void setRoutineReward(String routineType, String reward) {
    _routineRewards[routineType] = reward;
    notifyListeners();
    _saveToCloud();
  }

  // Mood Tracking
  String? _todaysMood;
  String? _todaysNote;
  String? get todaysMood => _todaysMood;
  String? get todaysNote => _todaysNote;
  Map<String, Map<String, String>> _moodHistory = {};
  Map<String, Map<String, String>> get moodHistory => _moodHistory;

  bool _isDataLoaded = false;
  bool get isDataLoaded => _isDataLoaded;

  // --- AMBIENT AUDIO ---
  bool _isPlayingAmbient = false;
  bool _isFading = false;
  bool get isPlayingAmbient => _isPlayingAmbient;

  final Set<String> _recentlyRestoredHabitIds = {};
  Set<String> get recentlyRestoredHabitIds => _recentlyRestoredHabitIds;

  String? _recentlyAddedHabitId;
  String? get recentlyAddedHabitId => _recentlyAddedHabitId;

  void setRecentlyAdded(String id) {
    _recentlyAddedHabitId = id;
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      if (_recentlyAddedHabitId == id) {
        _recentlyAddedHabitId = null;
        if (!_isDisposed) notifyListeners();
      }
    });
  }

  // --- PARTNER LINK ---
  bool _partnerRecentlyFinished = false;
  bool get partnerRecentlyFinished => _partnerRecentlyFinished;

  void triggerPartnerFinishedPulse() {
    _partnerRecentlyFinished = true;
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      _partnerRecentlyFinished = false;
      if (!_isDisposed) notifyListeners();
    });
  }

  String _getFormattedAssetPath() {
    String path = _selectedAudioTrack;
    // just_audio AudioSource.asset expects the full path
    if (!path.startsWith('assets/')) {
      path = 'assets/$path';
    }
    if (!path.endsWith('.mp3')) {
      path = 'assets/audio/hypnotic_loop.mp3';
    }
    return path;
  }

  ja.AudioSource _createAudioSource(String path) {
    final title = path
        .split('/')
        .last
        .split('.')
        .first
        .replaceAll('_', ' ')
        .toUpperCase();
    return ja.AudioSource.asset(
      path,
      tag: MediaItem(
        id: path,
        title: title,
        artist: 'Orbit Audio',
        // asset:/// URIs crash flutter_cache_manager (no HTTP host). Use a remote fallback.
        artUri: Uri.parse(
          'https://images.unsplash.com/photo-1444703686981-a3abbc4d4fe3?q=80&w=1000&auto=format&fit=crop',
        ),
      ),
    );
  }

  Future<void> _fadeOut() async {
    _isFading = true;
    double vol = _ambientPlayer.volume;
    while (vol > 0.05 && _isFading) {
      vol -= 0.05;
      await _ambientPlayer.setVolume(vol);
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (_isFading) {
      await _ambientPlayer.pause();
      _isFading = false;
    }
  }

  Future<void> _fadeIn() async {
    _isFading = true;
    await _ambientPlayer.setVolume(0);
    await _ambientPlayer.play();
    double vol = 0;
    while (vol < _ambientVolume && _isFading) {
      vol += 0.05;
      if (vol > _ambientVolume) vol = _ambientVolume;
      await _ambientPlayer.setVolume(vol);
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (_isFading) {
      await _ambientPlayer.setVolume(_ambientVolume);
      _isFading = false;
    }
  }

  Future<void> toggleAmbientAudio() async {
    _isFading = false; // Cancel any ongoing fade
    try {
      if (_isPlayingAmbient) {
        await _fadeOut();
      } else {
        if (_ambientPlayer.audioSource == null) {
          await _ambientPlayer.setAudioSource(
            _createAudioSource(_getFormattedAssetPath()),
          );
        }
        await _ambientPlayer.setLoopMode(ja.LoopMode.one);
        await _fadeIn();
      }
    } catch (e) {
      debugPrint('Audio Playback Error: $e');
      // Fallback: Just toggle play/pause without fading
      _isPlayingAmbient = false;
      notifyListeners();
    }
  }

  Future<void> stopAmbientAudio() async {
    _isFading = false;
    if (_isPlayingAmbient) {
      await _fadeOut();
    }
  }

  Future<void> setAmbientTrack(String path) async {
    _isFading = false;
    _selectedAudioTrack = path;
    _prefs?.setString('audio_track', path);
    _saveToCloud();

    try {
      await _ambientPlayer.setAudioSource(
        _createAudioSource(_getFormattedAssetPath()),
      );
      if (_isPlayingAmbient) {
        await _ambientPlayer.setLoopMode(ja.LoopMode.one);
        await _fadeIn();
      }
    } catch (e) {
      debugPrint('Audio Load Error (Is the file in assets?): $e');
      _isPlayingAmbient = false; // Stop the UI from acting like it's playing
    }
    notifyListeners();
  }

  // --- ACHIEVEMENTS ---
  bool _unlockedReaderBadge = false;
  bool get unlockedReaderBadge => _unlockedReaderBadge;

  // --- SECRET FAIRY EASTER EGG ---
  int _fairyTaps = 0;
  bool _unlockedFairyBadge = false;
  bool get unlockedFairyBadge => _unlockedFairyBadge;

  bool incrementFairyTaps() {
    _fairyTaps++;
    _prefs?.setInt('fairy_taps', _fairyTaps);
    if (_fairyTaps >= 10 && !_unlockedFairyBadge) {
      _unlockedFairyBadge = true;
      _prefs?.setBool('unlocked_fairy_badge', true);
      _saveToCloud();
      return true; // Tells the UI to pop the badge!
    }
    return false;
  }

  // --- LETTERS READ TODAY ---
  int _lettersReadToday = 0;
  int get lettersReadToday => _lettersReadToday;

  void incrementLettersReadToday() {
    _lettersReadToday++;
    _prefs?.setInt('letters_read_today', _lettersReadToday);
    if (_lettersReadToday >= 3 && !_unlockedReaderBadge) {
      _unlockedReaderBadge = true;
      _prefs?.setBool('unlocked_reader_badge', true);
      _saveToCloud();
    }
    notifyListeners();
  }

  // --- BOOKMARKS ---
  List<String> _bookmarkedQuotes = [];
  List<String> get bookmarkedQuotes => _bookmarkedQuotes;

  void toggleBookmark(String quote) {
    if (_bookmarkedQuotes.contains(quote)) {
      _bookmarkedQuotes.remove(quote);
    } else {
      _bookmarkedQuotes.add(quote);
    }
    notifyListeners();
    _prefs?.setStringList('bookmarked_quotes', _bookmarkedQuotes);
    _saveToCloud();
  }

  // --- INTERESTS ---
  List<String> _interests = [];
  List<String> get interests => _interests;

  /// Replaces the user's focus interests (drives Daily Wisdom's category
  /// pick and the AI coach's focus areas). Interests were previously
  /// write-once at onboarding with no way to change them after. Writes
  /// directly to Firestore ('interests' is not part of _saveToCloud()'s
  /// map -- onboarding writes it directly too). Returns null on success
  /// or a user-facing error message.
  Future<String?> setInterests(List<String> interests) async {
    final previous = _interests;
    _interests = List.of(interests);
    notifyListeners();
    try {
      await _db.collection('users').doc(_userId).update({
        'interests': _interests,
      });
      return null;
    } catch (e) {
      debugPrint('Failed to save interests: $e');
      _interests = previous;
      notifyListeners();
      return 'Could not save your interests. Please try again.';
    }
  }

  // APP SETTINGS (Wired to SharedPreferences
  bool _soundsEnabled = true;
  bool _hapticsEnabled = true;
  String _themeMode = 'System'; // Dark / Light mode
  bool _allNotifsEnabled = true;
  bool _dailySummaryNotifs = true;
  bool _morningNotifs = true;
  bool _nightNotifs = true;
  bool _streakNotifs = true;
  String _selectedAudioTrack = 'Space Hum';
  double _ambientVolume = 0.5;
  String _selectedAvatar = 'rocket'; // Default avatar
  bool _confettiEnabled = true;
  // Habit ID pinned to the iOS/Android "Habit Widget" home-screen widget --
  // null means nothing is featured (widget shows a pick-one prompt).
  String? _featuredHabitId;

  String? get featuredHabitId => _featuredHabitId;

  bool get soundsEnabled => _soundsEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  String get themeMode => _themeMode;
  bool get allNotifsEnabled => _allNotifsEnabled;
  bool get dailySummaryNotifs => _dailySummaryNotifs;
  bool get morningNotifs => _morningNotifs;
  bool get nightNotifs => _nightNotifs;
  bool get streakNotifs => _streakNotifs;

  String get selectedAudioTrack {
    if (_selectedAudioTrack == 'Space Hum' ||
        !_selectedAudioTrack.endsWith('.mp3')) {
      return 'assets/audio/hypnotic_loop.mp3';
    }
    return _selectedAudioTrack;
  }

  double get ambientVolume => _ambientVolume;
  String get selectedAvatar => _selectedAvatar;
  bool get confettiEnabled => _confettiEnabled;

  void setSounds(bool val) {
    _soundsEnabled = val;
    _prefs?.setBool('sounds', val);
    notifyListeners();
  }

  void setHaptics(bool val) {
    _hapticsEnabled = val;
    _prefs?.setBool('haptics', val);
    notifyListeners();
  }

  void setTheme(String val) {
    _themeMode = val;
    _prefs?.setString('theme', val);
  }

  void setAllNotifsEnabled(bool val) {
    _allNotifsEnabled = val;
    _prefs?.setBool('all_notifs', val);
    notifyListeners();
    _syncAlarms('Morning');
    _syncAlarms('Work');
    _syncAlarms('Night');
    // This master toggle previously only ever touched routine alarms --
    // the daily reminder and every per-habit reminder kept firing
    // regardless of it. Sweep them too, both ways: cancel everything on
    // disable, restore exactly what was configured on re-enable.
    if (val) {
      NotificationService.scheduleDailyReminder();
      for (final habit in _habits.values) {
        if (habit.remindersEnabled) {
          NotificationService.scheduleHabitReminder(habit);
        }
      }
    } else {
      NotificationService.cancelAlarm(999); // scheduleDailyReminder's fixed id
      for (final habit in _habits.values) {
        if (habit.remindersEnabled) {
          NotificationService.cancelHabitReminder(habit.id);
        }
      }
    }
  }

  void setDailySummaryNotifs(bool val) {
    _dailySummaryNotifs = val;
    _prefs?.setBool('daily_summary_notifs', val);
    notifyListeners();
    _saveToCloud();
  }

  void setMorningNotifs(bool val) {
    _morningNotifs = val;
    _prefs?.setBool('m_notifs', val);
    notifyListeners();
    _syncAlarms('Morning');
  }

  void setAmbientVolume(double val) {
    _ambientVolume = val;
    _prefs?.setDouble('ambient_volume', val);
    notifyListeners();
    _saveToCloud();
  }

  void setNightNotifs(bool val) {
    _nightNotifs = val;
    _prefs?.setBool('n_notifs', val);
    notifyListeners();
    _syncAlarms('Night');
  }

  void setStreakNotifs(bool val) {
    _streakNotifs = val;
    _prefs?.setBool('s_notifs', val);
    notifyListeners();
  }

  void setAvatar(String val) {
    _selectedAvatar = val;
    _prefs?.setString('avatar', val);
    notifyListeners();
    _saveToCloud();
  }

  void setConfetti(bool val) {
    _confettiEnabled = val;
    _prefs?.setBool('confetti', val);
    notifyListeners();
  }

  // STATS & STREAKS
  // All start at 0 -- these used to default to fake "demo" values (streak
  // 2, longest 7, completed 24, assigned 30) that made a brand-new user's
  // very first dashboard advertise fabricated progress: a "2 day streak"
  // they never earned, a 7-day longest, and an 80% (24/30) lifetime
  // completion rate before completing anything, plus a pre-unlocked first
  // Journey milestone. lifetimeCompletionRate already guards assigned==0.
  int _currentStreak = 0;
  bool _hasIncreasedStreakToday = false;
  int _longestStreak = 0;
  int _totalHabitsCompleted = 0;
  int _totalHabitsAssigned = 0;
  int _xp = 0;
  Map<String, int> _xpHistory = {};

  // A streak that would otherwise break gets absorbed by one of these
  // instead, purchased with the per-habit XP above (buyStreakFreeze cloud
  // function — previously wired server-side with no client ever calling
  // it, viewing the count, or consuming one).
  int _streakFreezes = 0;
  bool _isStreakFrozen = false;
  bool _isBuyingFreeze = false;

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalHabitsCompleted => _totalHabitsCompleted;
  int get totalHabitsAssigned => _totalHabitsAssigned;
  int get xp => _xp;
  Map<String, int> get xpHistory => _xpHistory;
  int get streakFreezes => _streakFreezes;
  bool get isStreakFrozen => _isStreakFrozen;
  bool get isBuyingFreeze => _isBuyingFreeze;
  static const int streakFreezeCost = 200;
  int get currentLevel => (_xp ~/ 100) + 1; // Level up every 100 XP
  double get levelProgress => (_xp % 100) / 100.0; // Progress to the next level
  bool get justLeveledUp => _justLeveledUp;
  double get lifetimeCompletionRate => _totalHabitsAssigned == 0
      ? 0.0
      : ((_totalHabitsCompleted / _totalHabitsAssigned) * 100).clamp(
          0.0,
          100.0,
        );
  // growable: true is load-bearing -- _checkDailyReset() calls
  // .removeAt(0)/.add() on this list, and it can run against this default
  // (before the real list is loaded from prefs a few lines later in
  // _loadData()'s cached-habits fast path) on every user's first cold
  // launch of a new calendar day. A plain List.filled() defaults to
  // fixed-length, which made that removeAt() throw "Unsupported
  // operation: Cannot remove from a fixed-length list" and crash the app.
  List<double> _weeklyProgress = List.filled(7, 0.0, growable: true);
  List<double> get weeklyProgress => _weeklyProgress;

  // --- JOURNEY PROGRESS ---
  Map<String, int> _unlockedJourneyChapters = {};

  int getUnlockedChapters(String journeyTitle) {
    return _unlockedJourneyChapters[journeyTitle] ??
        1; // Chapter 1 is always unlocked by default
  }

  void unlockChapter(String journeyTitle, int chapterNumber) {
    int current = getUnlockedChapters(journeyTitle);
    if (chapterNumber > current) {
      _unlockedJourneyChapters[journeyTitle] = chapterNumber;
      notifyListeners();
      _saveToCloud();
    }
  }

  // --- FOCUS JOURNEYS (per-category chapter progress) ---
  // Each of the 5 stellar-planet categories (see StellarPlanetVariant) is
  // its own "journey" that advances a chapter every [_chapterSize] habit
  // completions logged against habits tagged with that category, capped at
  // [_maxChapters]. Built on top of the existing unlockChapter/
  // getUnlockedChapters storage, keyed by the display label below.
  static const Map<String, String> focusJourneyLabels = {
    'fitness': 'Fitness',
    'mind': 'Mind',
    'productivity': 'Productivity',
    'growth': 'Growth',
    'core': 'Core',
  };
  static const int chapterSize = 5;
  static const int maxChapters = 5;
  // Paid from the same _xp pool habit completions already earn (10 XP
  // each) and streak freezes / Nebula Themes already spend — a full
  // journey (chapter 1 -> 5) takes 20 completions, so this is a
  // meaningfully larger payoff than any single day's grind.
  static const int journeyCompletionBonusXp = 150;

  // Set the day a journey first reaches maxChapters; cleared once the UI
  // shows the celebration, mirroring the (previously dormant, now reused)
  // _justLeveledUp/acknowledgeLevelUp pattern below.
  String? _justCompletedJourney;
  String? get justCompletedJourney => _justCompletedJourney;
  void acknowledgeJourneyCompletion() {
    _justCompletedJourney = null;
  }

  /// Total completed days logged across every habit tagged with [category]
  /// (a StellarPlanetVariant name, e.g. 'fitness').
  int categoryCompletions(String category) {
    return _habits.values
        .where((h) => h.category == category)
        .fold(0, (total, h) => total + h.completedDays);
  }

  int categoryChapter(String category) {
    final label = focusJourneyLabels[category];
    if (label == null) return 1;
    return getUnlockedChapters(label);
  }

  /// Progress (0.0-1.0) toward the *next* chapter for [category], or 1.0
  /// once the final chapter is reached.
  double categoryChapterProgress(String category) {
    if (categoryChapter(category) >= maxChapters) return 1.0;
    return (categoryCompletions(category) % chapterSize) / chapterSize;
  }

  /// Re-derives each category's unlocked chapter from its completion tally
  /// and persists any new unlock. Idempotent — safe to call every day-reset
  /// since unlockChapter() only writes when a chapter actually advances.
  void _checkFocusJourneyUnlocks() {
    for (final category in focusJourneyLabels.keys) {
      final label = focusJourneyLabels[category]!;
      final previousChapter = getUnlockedChapters(label);
      final completions = categoryCompletions(category);
      final targetChapter = (1 + completions ~/ chapterSize).clamp(
        1,
        maxChapters,
      );
      unlockChapter(label, targetChapter);

      if (targetChapter == maxChapters && previousChapter < maxChapters) {
        _xp += journeyCompletionBonusXp;
        final today = DateTime.now().toIso8601String().substring(0, 10);
        _xpHistory[today] = (_xpHistory[today] ?? 0) + journeyCompletionBonusXp;
        _prefs?.setInt('xp', _xp);
        // Only surface one celebration at a time — if two journeys finish
        // on the same day-reset, the rest still got their XP, just not a
        // popup (extremely rare, and each one still shows once it's the
        // only outstanding completion).
        _justCompletedJourney ??= label;
      }
    }
  }

  // --- NEBULA THEMES ---
  List<String> _unlockedThemes = ['Default'];
  String _activeNebulaTheme = 'Default';
  bool _isBuyingTheme = false;

  List<String> get unlockedThemes => _unlockedThemes;
  String get activeNebulaTheme => _activeNebulaTheme;
  bool get isBuyingTheme => _isBuyingTheme;

  /// Spends the theme's XP cost (the unlockNebulaTheme callable's own
  /// price) to permanently unlock a Nebula Theme. Returns null on success,
  /// or a user-facing error message on failure.
  Future<String?> unlockTheme(String theme) async {
    if (_isBuyingTheme || _unlockedThemes.contains(theme)) return null;

    if (DevOverrides.storeIsFreeInDebug) {
      _unlockedThemes.add(theme);
      notifyListeners();
      _saveToCloud();
      return null;
    }

    _isBuyingTheme = true;
    notifyListeners();

    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('unlockNebulaTheme').call({'theme': theme});

      final data = Map<String, dynamic>.from(result.data as Map);
      _unlockedThemes.add(theme);
      if (data['newXp'] is int) {
        _xp = data['newXp'] as int;
      } else {
        _xp -= NebulaThemes.byName(theme).cost;
      }
      _prefs?.setInt('xp', _xp);
      _saveToCloud();
      return null;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        return 'Not enough XP — habits earn 10 XP each.';
      }
      return e.message ?? 'Could not reach the Orbit Store.';
    } catch (e) {
      debugPrint('unlockTheme error: $e');
      return 'Could not reach the Orbit Store.';
    } finally {
      _isBuyingTheme = false;
      notifyListeners();
    }
  }

  void setActiveNebulaTheme(String theme) {
    if (_unlockedThemes.contains(theme)) {
      _activeNebulaTheme = theme;
      _prefs?.setString('active_nebula_theme', theme);
      notifyListeners();
      _saveToCloud();
    }
  }

  void acknowledgeLevelUp() {
    _justLeveledUp = false;
    // No notifyListeners() here to prevent an extra rebuild loop.
  }

  // We call this whenever a habit is checked off
  void incrementTotalHabits() {
    _totalHabitsCompleted++;
    _xp += 10; // Earn 10 XP per habit!

    String today = DateTime.now().toIso8601String().substring(0, 10);
    _xpHistory[today] = (_xpHistory[today] ?? 0) + 10;

    _prefs?.setInt('xp', _xp);
    _prefs?.setInt('total_habits_completed', _totalHabitsCompleted);
    FirebaseCrashlytics.instance.setCustomKey('user_level', currentLevel);
    FirebaseCrashlytics.instance.setCustomKey('user_xp', _xp);
    FirebaseCrashlytics.instance.setCustomKey('current_streak', _currentStreak);
  }

  // A unified map to hold all habit objects, keyed by their ID.
  Map<String, Habit> _habits = {};
  Map<String, Habit> get habits => _habits;

  // --- UPGRADED ALARMS (Time + Days combined!) ---
  final Map<String, List<RoutineAlarm>> _routineAlarms = {
    'Morning': [
      RoutineAlarm(
        time: '07:00',
        activeDays: [true, true, true, true, true, false, false],
      ),
    ],
    'Work': [
      RoutineAlarm(
        time: '13:00',
        activeDays: [true, true, true, true, true, false, false],
      ),
    ],
    'Night': [
      RoutineAlarm(
        time: '20:30',
        activeDays: [true, true, true, true, true, true, true],
      ),
    ],
  };

  // Get the complex alarm objects for the settings screen
  List<RoutineAlarm> getRoutineAlarms(String routineType) {
    return _routineAlarms[routineType] ?? [];
  }

  // Get just the strings for the Dashboard UI
  List<String> getRoutineTimes(String routineType) {
    return (_routineAlarms[routineType] ?? []).map((a) => a.time).toList();
  }

  void updateRoutineTime(String routineType, int index, String newTime) {
    if (_routineAlarms[routineType] != null) {
      _routineAlarms[routineType]![index].time = newTime;
      notifyListeners();
      _syncAlarms(routineType);
    }
  }

  void toggleAlarmDay(String routineType, int alarmIndex, int dayIndex) {
    if (_routineAlarms[routineType] != null) {
      _routineAlarms[routineType]![alarmIndex].activeDays[dayIndex] =
          !_routineAlarms[routineType]![alarmIndex].activeDays[dayIndex];
      notifyListeners();
      _syncAlarms(routineType);
    }
  }

  // NotificationService.scheduleRoutineAlarms IDs each alarm as
  // offset + i*7 + day (i = alarm index, day 0-6) and reserves
  // offset+60..+66 for the group summary notification -- an unbounded
  // alarm count lets a routine's own alarm IDs collide with its summary
  // slot (from the 9th alarm on) or exceed cancelAlarms' fixed 0..69
  // cleanup range, leaving orphaned "ghost" notifications that survive
  // deletion. 8 alarms keeps the max ID at offset+55, safely under +60.
  static const int maxAlarmsPerRoutine = 8;

  /// Returns false (and adds nothing) if [routineType] is already at the
  /// max alarm count.
  bool addRoutineAlarm(String routineType, String newTime) {
    _routineAlarms[routineType] ??= [];
    if (_routineAlarms[routineType]!.length >= maxAlarmsPerRoutine) {
      return false;
    }
    // Default new alarms to Monday-Friday!
    _routineAlarms[routineType]!.add(
      RoutineAlarm(
        time: newTime,
        activeDays: [true, true, true, true, true, false, false],
      ),
    );
    notifyListeners();
    _syncAlarms(routineType);
    return true;
  }

  void removeRoutineAlarm(String routineType, int index) {
    if (_routineAlarms[routineType] != null) {
      _routineAlarms[routineType]!.removeAt(index);
      notifyListeners();
      _syncAlarms(routineType);
    }
  }

  /// Force-syncs all routine alarms. Useful for restoring alarms if manually cancelled.
  void resyncAllAlarms() {
    _syncAlarms('Morning', save: false);
    _syncAlarms('Work', save: false);
    _syncAlarms('Night', save: false);
  }

  void _syncAlarms(String routineType, {bool save = true}) {
    final shouldSchedule =
        _allNotifsEnabled &&
        !(routineType == 'Morning' && !_morningNotifs) &&
        !(routineType == 'Night' && !_nightNotifs);

    if (shouldSchedule) {
      // scheduleRoutineAlarms already does its own cancelAlarms() before
      // scheduling -- calling it again here too (both un-awaited, racing
      // each other) risked this second, slower sweep finishing *after*
      // scheduleRoutineAlarms had already placed the fresh alarms,
      // silently wiping out a just-added/edited one.
      NotificationService.scheduleRoutineAlarms(
        routineType,
        _routineAlarms[routineType] ?? [],
      );
    } else {
      // Nothing will call cancelAlarms() on our behalf in this branch, so
      // it's still needed here.
      NotificationService.cancelAlarms(routineType);
    }
    // Always persist, regardless of which branch above fired — a toggle
    // turned off should sync to the cloud the same as one turned on.
    if (save) {
      _saveToCloud();
    }
  }

  final Map<String, bool> _completedHabits = {};
  String? _lastResetDate;

  RoutineProvider({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    audioplayers.AudioPlayer? audioPlayer,
    ja.AudioPlayer? ambientPlayer,
  }) : _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _audioPlayer = audioPlayer ?? audioplayers.AudioPlayer(),
       _ambientPlayer = ambientPlayer ?? ja.AudioPlayer() {
    WidgetsBinding.instance.addObserver(this);

    _ambientPlayer.playerStateStream.listen((state) {
      if (_isPlayingAmbient != state.playing) {
        _isPlayingAmbient = state.playing;
        // Use addPostFrameCallback — NOT Future.microtask.
        //
        // just_audio's playerStateStream is backed by a RxDart BehaviorSubject
        // which delivers events synchronously. If play() is called from
        // initState (as CoachingSessionScreen does), the stream can fire while
        // Flutter's build phase is active (debugBuildingDirtyElements = true).
        // Future.microtask fires in the microtask queue between synchronous
        // steps of the current Dart event, which CAN overlap with the build
        // phase, causing "dirty widget in wrong build scope" (framework.dart
        // line 6417). addPostFrameCallback defers until after the entire
        // build+layout+paint cycle, guaranteeing no active build exists.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed) notifyListeners();
        });
      }
    });

    // Listen for the exact moment Firebase wakes up and confirms who is logged in
    _authSubscription = _auth.authStateChanges().listen((user) async {
      final newUid = user?.uid;
      // SharedPreferences keys below (current_streak, xp, avatar,
      // cached_habits_data, etc.) are NOT namespaced by uid -- without
      // this, a second account signing in on the same device in the same
      // app session (no restart) would briefly show, or for any field
      // its own cloud doc doesn't set, permanently show, the previous
      // account's streak/XP/avatar/cached habits. Only clear on an actual
      // switch (_previousUid already set to something else), not on the
      // very first sign-in of a fresh launch.
      if (_previousUid != null && newUid != _previousUid) {
        await _clearLocalStateForAccountSwitch();
      }
      _previousUid = newUid;
      if (user != null) {
        _loadData();
      }
    });

    _scheduleMidnightRollover();
  }

  Future<void> _clearLocalStateForAccountSwitch() async {
    _habits = {};
    _completedHabits.clear();
    _isDataLoaded = false;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // _checkDailyReset() previously only ran on init/cloud-load and on
  // AppLifecycleState.resumed -- a user who keeps the app open across local
  // midnight (journaling, checking stats late at night) kept _lastResetDate
  // stuck on the prior day, so habit toggles/XP/mood entries made after
  // midnight were still stamped with yesterday's date key until the app was
  // backgrounded and resumed. Self-reschedules for every following midnight.
  void _scheduleMidnightRollover() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (_isDisposed) return;
      _checkDailyReset();
      _scheduleMidnightRollover();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authSubscription?.cancel();
    _midnightTimer?.cancel();
    _saveDebounceTimer?.cancel();
    _audioPlayer.dispose();
    _ambientPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app comes to the foreground, check if it's a new day!
    if (state == AppLifecycleState.resumed) {
      _checkDailyReset();
    }
  }

  // HELPER: Get the right list based on the routine string
  List<Habit> getHabitsForRoutine(String routineType) {
    final routineHabits = _habits.values
        .where((h) => h.routineType == routineType && !h.isArchived)
        .toList();
    // Sort by the 'order' property to maintain user-defined sequence
    routineHabits.sort((a, b) => a.order.compareTo(b.order));
    return routineHabits;
  }

  /// Habits currently paused (isArchived) -- for a dedicated management
  /// view; excluded from getHabitsForRoutine() and from being counted as a
  /// "miss" (see Habit.isArchived for the couple of deliberate exceptions
  /// where a genuine completion still counts).
  List<Habit> get archivedHabits =>
      _habits.values.where((h) => h.isArchived).toList()
        ..sort((a, b) => a.title.compareTo(b.title));

  Future<void> setHabitArchived(String habitId, bool archived) async {
    final habit = _habits[habitId];
    if (habit == null) return;
    habit.isArchived = archived;
    _db
        .collection('users')
        .doc(_userId)
        .collection('habits')
        .doc(habitId)
        .update({'isArchived': archived})
        .catchError((e) {
          debugPrint('Failed to sync isArchived for $habitId: $e');
        });
    // Pausing is meant to stop the nagging too, not just the daily-checklist
    // penalty -- and resuming should bring the reminder back exactly as it
    // was configured (scheduleHabitReminder no-ops if remindersEnabled is
    // false, so this is safe to call unconditionally either way).
    if (archived) {
      NotificationService.cancelHabitReminder(habitId);
    } else {
      NotificationService.scheduleHabitReminder(habit);
    }
    notifyListeners();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    _lastResetDate = _prefs?.getString('last_reset_date');
    _dailyIntention = _prefs?.getString('daily_intention');
    _todaysMood = _prefs?.getString('todays_mood');
    _todaysNote = _prefs?.getString('todays_note');
    _soundsEnabled = _prefs?.getBool('sounds') ?? true;
    _allNotifsEnabled = _prefs?.getBool('all_notifs') ?? true;
    _dailySummaryNotifs = _prefs?.getBool('daily_summary_notifs') ?? true;
    _morningNotifs = _prefs?.getBool('m_notifs') ?? true;
    _nightNotifs = _prefs?.getBool('n_notifs') ?? true;
    _currentStreak = _prefs?.getInt('current_streak') ?? 0;
    _themeMode = _prefs?.getString('theme') ?? 'System';
    _selectedAudioTrack = _prefs?.getString('audio_track') ?? 'Space Hum';
    _ambientVolume = _prefs?.getDouble('ambient_volume') ?? 0.5;
    _hasIncreasedStreakToday =
        _prefs?.getBool('streak_increased_today') ?? false;
    _longestStreak = _prefs?.getInt('longest_streak') ?? 0;
    _totalHabitsAssigned = _prefs?.getInt('total_habits_assigned') ?? 0;
    // Previously never persisted at all -- it reset to its in-memory
    // default on every cold start, so lifetime completion rate was really
    // per-session and the Centurion achievement (>= 100 lifetime) could
    // never actually accrue. Now loaded/saved like its sibling stats.
    _totalHabitsCompleted = _prefs?.getInt('total_habits_completed') ?? 0;
    _xp = _prefs?.getInt('xp') ?? 0;
    _streakFreezes = _prefs?.getInt('streak_freezes') ?? 0;
    _isStreakFrozen = _prefs?.getBool('is_streak_frozen') ?? false;
    _selectedAvatar = _prefs?.getString('avatar') ?? 'rocket';
    _featuredHabitId = _prefs?.getString('featured_habit_id');
    _bookmarkedQuotes = _prefs?.getStringList('bookmarked_quotes') ?? [];
    _lettersReadToday = _prefs?.getInt('letters_read_today') ?? 0;
    _unlockedReaderBadge = _prefs?.getBool('unlocked_reader_badge') ?? false;
    _confettiEnabled = _prefs?.getBool('confetti') ?? true;
    _activeNebulaTheme = _prefs?.getString('active_nebula_theme') ?? 'Default';
    _lowPowerMode = _prefs?.getBool('lowPowerMode') ?? false;
    _fairyTaps = _prefs?.getInt('fairy_taps') ?? 0;
    _unlockedFairyBadge = _prefs?.getBool('unlocked_fairy_badge') ?? false;

    // --- OFFLINE CACHE: LOAD HABITS INSTANTLY ---
    try {
      final cachedHabitsStr = _prefs?.getString('cached_habits_data');
      if (cachedHabitsStr != null) {
        final List<dynamic> decoded = jsonDecode(cachedHabitsStr);
        final loadedHabits = <String, Habit>{};
        for (var item in decoded) {
          final data = item as Map<String, dynamic>;
          final id = data['id'] as String;
          final isCompleted = data['isCompleted'] as bool? ?? false;
          loadedHabits[id] = Habit.fromMap(id, data, isCompleted: isCompleted);
          _completedHabits[id] = isCompleted;
        }
        _habits = loadedHabits;
        _checkDailyReset(); // Process new-day logic with cached data instantly!
        _isDataLoaded = true;
        notifyListeners(); // UI renders instantly!
      }
    } catch (e) {
      debugPrint('Error loading cached habits: $e');
    }

    // Load weekly progress. tryParse + whereType, not parse -- this runs
    // during app init and sits outside the cached-habits try/catch above,
    // so a single malformed/corrupt cached entry used to throw and break
    // the whole load for that user on every launch.
    final history =
        _prefs
            ?.getStringList('weekly_progress_history')
            ?.map(double.tryParse)
            .whereType<double>()
            .toList() ??
        [];
    if (history.length < 7) {
      _weeklyProgress = [...List.filled(7 - history.length, 0.0), ...history];
    } else if (history.length > 7) {
      _weeklyProgress = history.sublist(history.length - 7);
    } else {
      _weeklyProgress = history;
    }

    try {
      DocumentSnapshot doc = await _db
          .collection('users')
          .doc(_userId)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      if (_isDisposed) return;

      if (doc.exists) {
        Map<String, dynamic> cloudData =
            doc.data() as Map<String, dynamic>? ?? {};

        if (cloudData.containsKey('routine_rewards')) {
          _routineRewards = Map<String, String>.from(
            cloudData['routine_rewards'],
          );
        }

        if (cloudData.containsKey('audio_track')) {
          _selectedAudioTrack = cloudData['audio_track'];
        }
        if (cloudData.containsKey('ambient_volume')) {
          _ambientVolume = cloudData['ambient_volume'];
        }
        if (cloudData.containsKey('all_notifs')) {
          _allNotifsEnabled = cloudData['all_notifs'];
        }
        if (cloudData.containsKey('daily_summary_notifs')) {
          _dailySummaryNotifs = cloudData['daily_summary_notifs'];
        }
        if (cloudData.containsKey('morning_notifs')) {
          _morningNotifs = cloudData['morning_notifs'];
        }
        if (cloudData.containsKey('night_notifs')) {
          _nightNotifs = cloudData['night_notifs'];
        }
        if (cloudData.containsKey('avatar')) {
          _selectedAvatar = cloudData['avatar'];
        }
        if (cloudData.containsKey('featured_habit_id')) {
          _featuredHabitId = cloudData['featured_habit_id'];
        }

        // Load the daily completion status (the old way, for compatibility)
        if (cloudData.containsKey('habits')) {
          Map<String, dynamic> cloudHabits = cloudData['habits'];
          cloudHabits.forEach((key, value) {
            _completedHabits[key] = value as bool;
          });
        }

        if (cloudData.containsKey('current_streak')) {
          _currentStreak = cloudData['current_streak'];
        }
        if (cloudData.containsKey('streak_increased_today')) {
          _hasIncreasedStreakToday = cloudData['streak_increased_today'];
        }
        if (cloudData.containsKey('streakFreezes')) {
          _streakFreezes = cloudData['streakFreezes'];
        }
        if (cloudData.containsKey('isStreakFrozen')) {
          _isStreakFrozen = cloudData['isStreakFrozen'];
        }
        if (cloudData.containsKey('longest_streak')) {
          _longestStreak = cloudData['longest_streak'];
        }
        if (cloudData.containsKey('total_habits_assigned')) {
          _totalHabitsAssigned = cloudData['total_habits_assigned'];
        }
        if (cloudData.containsKey('total_habits_completed')) {
          _totalHabitsCompleted = cloudData['total_habits_completed'];
        }
        if (cloudData.containsKey('xp')) {
          _xp = cloudData['xp'];
        }
        if (cloudData.containsKey('xp_history')) {
          _xpHistory = Map<String, int>.from(cloudData['xp_history']);
        }

        if (cloudData.containsKey('unlocked_journey_chapters')) {
          _unlockedJourneyChapters = Map<String, int>.from(
            cloudData['unlocked_journey_chapters'],
          );
        }

        if (cloudData.containsKey('mood_history')) {
          _moodHistory = Map<String, Map<String, String>>.from(
            cloudData['mood_history'].map(
              (key, value) => MapEntry(key, Map<String, String>.from(value)),
            ),
          );
        }

        if (cloudData.containsKey('bookmarked_quotes')) {
          _bookmarkedQuotes = List<String>.from(cloudData['bookmarked_quotes']);
        }

        if (cloudData.containsKey('intention_history')) {
          _intentionHistory = Map<String, String>.from(
            cloudData['intention_history'],
          );
        }

        if (cloudData.containsKey('unlocked_reader_badge')) {
          _unlockedReaderBadge = cloudData['unlocked_reader_badge'];
        }
        if (cloudData.containsKey('unlocked_fairy_badge')) {
          _unlockedFairyBadge = cloudData['unlocked_fairy_badge'];
        }
        if (cloudData.containsKey('fairy_taps')) {
          _fairyTaps = cloudData['fairy_taps'];
        }

        if (cloudData.containsKey('unlocked_themes')) {
          _unlockedThemes = List<String>.from(cloudData['unlocked_themes']);
        }
        if (cloudData.containsKey('active_nebula_theme')) {
          _activeNebulaTheme = cloudData['active_nebula_theme'];
        }

        FirebaseCrashlytics.instance.setCustomKey(
          'current_streak',
          _currentStreak,
        );
        if (cloudData.containsKey('interests')) {
          _interests =
              (cloudData['interests'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final focusAreas = _interests.join(', ');
          FirebaseCrashlytics.instance.setCustomKey(
            'active_focus_areas',
            focusAreas.isEmpty ? 'None' : focusAreas,
          );
        }

        // Load alarms from Firebase
        if (cloudData.containsKey('routine_alarms')) {
          Map<String, dynamic> alarmsData = cloudData['routine_alarms'];
          alarmsData.forEach((key, value) {
            _routineAlarms[key] = (value as List)
                .map((e) => RoutineAlarm.fromMap(e as Map<String, dynamic>))
                .toList();
            // Use _syncAlarms here to ensure old duplicate ghost alarms are cleared!
            _syncAlarms(key, save: false);
          });
        }

        // NEW: Load habits from their own subcollection
        final habitsSnapshot = await _db
            .collection('users')
            .doc(_userId)
            .collection('habits')
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 5));

        final loadedHabits = <String, Habit>{};
        for (var habitDoc in habitsSnapshot.docs) {
          // Use the previously loaded completion status to initialize the habit object
          final isCompleted = _completedHabits[habitDoc.id] ?? false;
          loadedHabits[habitDoc.id] = Habit.fromSnapshot(
            habitDoc,
            isCompleted: isCompleted,
          );
        }
        _habits = loadedHabits;

        _checkDailyReset();

        _isDataLoaded = true;
        notifyListeners();
      } else {
        _checkDailyReset();
        _isDataLoaded = true;
        notifyListeners();
      }
    } catch (e, stack) {
      debugPrint("Cloud sync failed: $e");
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Habit cloud sync failed during data load',
      );
      if (_isDisposed) return;
      _isDataLoaded = true;
      notifyListeners();
    }
  }

  void _checkDailyReset() {
    if (_prefs == null) return; // Wait until initial load finishes

    String today = DateTime.now().toIso8601String().substring(
      0,
      10,
    ); // Format: YYYY-MM-DD
    if (_lastResetDate != today) {
      // Capture the date that's ending before it gets overwritten below —
      // per-habit history entries below belong to this day, not "today".
      final String? completedDayKey = _lastResetDate;
      // Which activeDays slot the closing day falls on (1=Monday..7=Sunday
      // -> index 0-6) -- used below so a habit's Tue/Thu-only schedule
      // doesn't get tallied as "missed" on a Monday it was never due.
      final int? closingWeekday = completedDayKey != null
          ? DateTime.tryParse(completedDayKey)?.weekday
          : null;

      // --- NEW: Calculate and save yesterday's progress ---
      if (_lastResetDate != null) {
        // Don't run on first ever launch. Use the new _habits list.
        final allHabits = _habits.values.toList();
        // "Due" = actually scheduled for the closing day, or completed
        // anyway (voluntary extra effort always counts, never dilutes the
        // denominator with days a habit wasn't even supposed to run).
        // Archived (paused) habits are excluded the same way a not-
        // scheduled day is, unless they were completed anyway.
        final dueHabits = closingWeekday == null
            ? allHabits.where((h) => !h.isArchived).toList()
            : allHabits
                  .where(
                    (h) =>
                        h.isCompleted ||
                        (!h.isArchived && h.activeDays[closingWeekday - 1]),
                  )
                  .toList();
        final completedCount = dueHabits.where((h) => h.isCompleted).length;
        final yesterdayProgress = dueHabits.isEmpty
            ? 0.0
            : completedCount / dueHabits.length;

        // Update our list (remove oldest, add newest)
        _weeklyProgress.removeAt(0);
        _weeklyProgress.add(yesterdayProgress);

        // Add yesterday's actually-due habits to the lifetime pool!
        _totalHabitsAssigned += dueHabits.length;
        _prefs?.setInt('total_habits_assigned', _totalHabitsAssigned);

        _prefs?.setStringList(
          'weekly_progress_history',
          _weeklyProgress.map((d) => d.toString()).toList(),
        );
      }

      // --- STREAK LOGIC ---
      if (_lastResetDate != null) {
        try {
          DateTime last = DateTime.parse(_lastResetDate!);
          DateTime curr = DateTime.parse(today);
          // Diff via UTC-normalized dates, not the local-time DateTimes
          // DateTime.parse produces -- a local-time difference truncates
          // across a DST transition (a "day" can be 23h/25h wall-clock),
          // which could under/over-count real calendar days missed and
          // throw off both the streak-break threshold and freeze
          // eligibility below. UTC has no DST, so this is always exact.
          final daysMissed = DateTime.utc(
            curr.year,
            curr.month,
            curr.day,
          ).difference(DateTime.utc(last.year, last.month, last.day)).inDays;
          // If more than 1 day has passed, OR they didn't complete a routine yesterday, break streak!
          final wouldBreak = daysMissed > 1 || !_hasIncreasedStreakToday;

          // A freeze absorbs exactly one missed day (what it's priced
          // for) — being gone longer still breaks the streak.
          if (wouldBreak && _streakFreezes > 0 && daysMissed <= 2) {
            _streakFreezes--;
            _isStreakFrozen = true;
            _prefs?.setInt('streak_freezes', _streakFreezes);
            _prefs?.setBool('is_streak_frozen', true);
            // Push promptly so onFreezeConsumed (a Firestore trigger
            // watching for isStreakFrozen's false->true edge) fires and
            // notifies the user their streak was saved.
            _saveToCloud();
          } else if (wouldBreak) {
            _currentStreak = 0;
            _prefs?.setInt('current_streak', 0);
            FirebaseCrashlytics.instance.setCustomKey('current_streak', 0);
          }
        } catch (e) {
          debugPrint("Streak parsing error: $e");
        }
      }

      _hasIncreasedStreakToday = false;
      _prefs?.setBool('streak_increased_today', false);
      // --- END STREAK LOGIC ---

      _lastResetDate = today;
      _prefs?.setString('last_reset_date', today);
      _dailyIntention = null;
      _prefs?.remove('daily_intention');
      _todaysMood = null;
      _prefs?.remove('todays_mood');
      _todaysNote = null;
      _prefs?.remove('todays_note');

      _lettersReadToday = 0;
      _prefs?.remove('letters_read_today');

      _completedHabits.clear();
      // Reset the completion status on all loaded habit objects
      _habits.forEach((id, habit) {
        // Only tally a real day if there was a previous day to close out —
        // the very first reset after install/cloud-restore has no prior
        // date, so there's nothing to record yet. Also skip tallying a
        // habit that wasn't actually due on the closing day and wasn't
        // completed anyway -- it was never "missed" if it was never
        // scheduled, so it shouldn't count against totalDays/skippedCount
        // or leave a history entry at all. Same for an archived (paused)
        // habit -- pausing is meant to stop the penalty, not just hide it;
        // a genuine completion before archiving still counts either way.
        final wasDueOrDone =
            habit.isCompleted ||
            (!habit.isArchived &&
                closingWeekday != null &&
                habit.activeDays[closingWeekday - 1]);
        if (completedDayKey != null && wasDueOrDone) {
          // Self-heal the legacy habit-creation seed (totalDays used to
          // start at a vestigial 21/7 "goal" constant nothing ever
          // consumed) — if the tallies don't already add up, this habit
          // has never been through a real daily-reset cycle, so treat it
          // as day zero rather than inheriting the stale seed.
          if (habit.totalDays != habit.completedDays + habit.skippedCount) {
            habit.totalDays = habit.completedDays + habit.skippedCount;
          }
          habit.totalDays++;
          if (habit.isCompleted) {
            habit.completedDays++;
          } else {
            habit.skippedCount++;
          }
          habit.history[completedDayKey] = habit.isCompleted;
          _db
              .collection('users')
              .doc(_userId)
              .collection('habits')
              .doc(habit.id)
              .update({
                'totalDays': habit.totalDays,
                'completedDays': habit.completedDays,
                'skippedCount': habit.skippedCount,
                'history.$completedDayKey': habit.isCompleted,
              })
              .catchError((_) {});
        }
        habit.isCompleted = false;
        // Reset count-based habits' daily progress too -- no-op (stays 0)
        // for simple checkbox habits.
        habit.currentCount = 0;
      });

      _checkFocusJourneyUnlocks();

      notifyListeners();
      // The featured habit's streak can change here too (a miss recorded
      // above breaks it) without ever going through toggleHabit today.
      if (_featuredHabitId != null) _updateFeaturedHabitWidget();
      _saveToCloud(); // Sync the fresh day to Firebase immediately
    }
  }

  bool isHabitCompleted(String habitId) {
    return _habits[habitId]?.isCompleted ?? false;
  }

  // Checks if every habit *actually due today* in a specific routine is
  // done -- habits scheduled for other days (Habit.activeDays) don't count
  // toward "did you finish today," matching how they're excluded from the
  // daily-reset tally below.
  bool isRoutineComplete(String routineType) {
    List<Habit> habits = getHabitsForRoutine(
      routineType,
    ).where((h) => h.isActiveOn()).toList();
    if (habits.isEmpty) return false;
    return habits.every((habit) => isHabitCompleted(habit.id));
  }

  // Increases the streak when a routine is completed
  bool markRoutineComplete() {
    bool isNewLongest = false;
    if (!_hasIncreasedStreakToday) {
      _currentStreak++;
      if (_currentStreak > _longestStreak) {
        _longestStreak = _currentStreak;
        _prefs?.setInt('longest_streak', _longestStreak);
        isNewLongest = true;
      }
      _hasIncreasedStreakToday = true;
      _prefs?.setInt('current_streak', _currentStreak);
      _prefs?.setBool('streak_increased_today', true);
      if (_isStreakFrozen) {
        // Back to normal — lets a future missed day flip this false->true
        // again, which is what triggers the "streak saved" notification.
        _isStreakFrozen = false;
        _prefs?.setBool('is_streak_frozen', false);
      }
      FirebaseCrashlytics.instance.setCustomKey(
        'current_streak',
        _currentStreak,
      );

      notifyListeners();
      _saveToCloud();
    }
    return isNewLongest;
  }

  /// Spends [streakFreezeCost] XP (the buyStreakFreeze callable's own
  /// price) for one streak freeze. Returns null on success, or a
  /// user-facing error message on failure.
  Future<String?> buyStreakFreeze() async {
    if (_isBuyingFreeze) return null;
    _isBuyingFreeze = true;
    notifyListeners();

    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('buyStreakFreeze').call();

      final data = Map<String, dynamic>.from(result.data as Map);
      _streakFreezes++;
      if (data['newXp'] is int) {
        _xp = data['newXp'] as int;
      } else {
        _xp -= streakFreezeCost;
      }
      _prefs?.setInt('streak_freezes', _streakFreezes);
      _prefs?.setInt('xp', _xp);
      _saveToCloud();
      return null;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        return 'Not enough XP — habits earn 10 XP each.';
      }
      return e.message ?? 'Could not reach the Orbit Store.';
    } catch (e) {
      debugPrint('buyStreakFreeze error: $e');
      return 'Could not reach the Orbit Store.';
    } finally {
      _isBuyingFreeze = false;
      notifyListeners();
    }
  }

  Future<void> toggleHabit(String habitId) async {
    final habit = _habits[habitId];
    if (habit == null) return;

    habit.isCompleted = !habit.isCompleted;

    if (habit.isCompleted) {
      habit.skippedCount = 0;
      _db
          .collection('users')
          .doc(_userId)
          .collection('habits')
          .doc(habit.id)
          .update({'skippedCount': 0})
          .catchError((_) {});

      incrementTotalHabits(); // ALWAYS triggers on completion!

      // markRoutineComplete() (streak advancement) previously had exactly
      // one caller -- skipRoutine()'s bulk "skip remaining" action -- so
      // completing every habit one-by-one through the normal checklist UI
      // never advanced the streak at all. Check here too, the moment the
      // last habit in a routine is genuinely completed.
      if (isRoutineComplete(habit.routineType)) {
        markRoutineComplete();
      }

      if (_soundsEnabled) {
        try {
          await _audioPlayer.play(
            audioplayers.AssetSource('audio/success_chime.mp3'),
          );
        } catch (e, s) {
          debugPrint('Failed to play completion sound: $e');
          FirebaseCrashlytics.instance.recordError(
            e,
            s,
            reason: 'Failed to play completion sound',
          );
        }
      }
    }

    // For saving, we still update the old map for now.
    _completedHabits[habitId] = habit.isCompleted;

    if (_isDisposed) return;
    notifyListeners();
    _updateHomeWidget(); // Trigger home widget update on any habit toggle
    if (habitId == _featuredHabitId) _updateFeaturedHabitWidget();
    _saveToCloud();
  }

  /// Increments (or decrements, with a negative [delta]) a count-based
  /// habit's ("Drink 8 glasses of water") daily progress. No-op for a
  /// simple checkbox habit (targetCount == null) -- use toggleHabit() for
  /// those. isCompleted is derived from currentCount >= targetCount, so it
  /// stays the single source of truth everywhere else (streaks, stats,
  /// Focus Journeys) exactly like toggleHabit() -- this just drives it a
  /// different way.
  Future<void> incrementHabitCount(String habitId, {int delta = 1}) async {
    final habit = _habits[habitId];
    if (habit == null || habit.targetCount == null) return;

    final bool wasCompleted = habit.isCompleted;
    habit.currentCount = (habit.currentCount + delta).clamp(
      0,
      habit.targetCount!,
    );
    habit.isCompleted = habit.currentCount >= habit.targetCount!;

    _db
        .collection('users')
        .doc(_userId)
        .collection('habits')
        .doc(habit.id)
        .update({
          'currentCount': habit.currentCount,
          'isCompleted': habit.isCompleted,
        })
        .catchError((_) {});

    if (habit.isCompleted && !wasCompleted) {
      habit.skippedCount = 0;
      _db
          .collection('users')
          .doc(_userId)
          .collection('habits')
          .doc(habit.id)
          .update({'skippedCount': 0})
          .catchError((_) {});

      incrementTotalHabits(); // ALWAYS triggers on completion!

      if (isRoutineComplete(habit.routineType)) {
        markRoutineComplete();
      }

      if (_soundsEnabled) {
        try {
          await _audioPlayer.play(
            audioplayers.AssetSource('audio/success_chime.mp3'),
          );
        } catch (e, s) {
          debugPrint('Failed to play completion sound: $e');
          FirebaseCrashlytics.instance.recordError(
            e,
            s,
            reason: 'Failed to play completion sound',
          );
        }
      }
    }

    _completedHabits[habitId] = habit.isCompleted;

    if (_isDisposed) return;
    notifyListeners();
    _updateHomeWidget();
    if (habitId == _featuredHabitId) _updateFeaturedHabitWidget();
    _saveToCloud();
  }

  Map<String, dynamic>? skipRoutine(String routineType) {
    // Only skip what's actually due today -- marking a habit scheduled for
    // a different day "complete" via "skip remaining" doesn't make sense.
    List<Habit> habits = getHabitsForRoutine(
      routineType,
    ).where((h) => h.isActiveOn()).toList();
    List<Habit> skippedHabits = [];
    for (var habit in habits) {
      if (!isHabitCompleted(habit.id)) {
        _completedHabits[habit.id] = true;
        habit.isCompleted = true;
        habit.skippedCount++;
        _db
            .collection('users')
            .doc(_userId)
            .collection('habits')
            .doc(habit.id)
            .update({'skippedCount': habit.skippedCount})
            .catchError((e) {
              debugPrint('Failed to sync skippedCount: $e');
            });
        // skipped_sessions_screen.dart reads this subcollection but
        // nothing ever wrote to it — this is the actual "I'm skipping
        // this today" user action, so it's the natural place to log one.
        _db
            .collection('users')
            .doc(_userId)
            .collection('skipped_sessions')
            .add({
              'habitTitle': habit.title,
              'reason': 'Skipped without a reason',
              'timestamp': FieldValue.serverTimestamp(),
            })
            .then((_) {})
            .catchError((e) {
              debugPrint('Failed to log skipped session: $e');
            });
        // A complete "Second Chance" notification (title, body, dashboard
        // deep-link routing) already existed in NotificationService with
        // zero callers anywhere — this is the actual skip action it was
        // built for. 3 hours gives a same-day nudge without immediately
        // re-pestering someone who just explicitly skipped. Gated on the
        // master toggle -- this used to fire regardless of it.
        if (_allNotifsEnabled) {
          NotificationService.scheduleReattemptReminder(
            habit.id,
            habit.title,
            const Duration(hours: 3),
          );
        }
        skippedHabits.add(habit);
      }
    }
    if (skippedHabits.isNotEmpty) {
      bool streakIncreased = !_hasIncreasedStreakToday;
      bool isNewLongest = markRoutineComplete();
      notifyListeners();
      _saveToCloud();
      return {
        'skippedHabits': skippedHabits,
        'streakIncreased': streakIncreased,
        'isNewLongest': isNewLongest,
      };
    }
    return null;
  }

  void undoSkipRoutine(
    List<Habit> revertedHabits,
    bool streakIncreased,
    bool isNewLongest,
  ) {
    for (var habit in revertedHabits) {
      _completedHabits[habit.id] = false;
      habit.isCompleted = false;
    }
    if (streakIncreased) {
      _currentStreak--;
      _hasIncreasedStreakToday = false;
      if (isNewLongest) {
        _longestStreak--;
        _prefs?.setInt('longest_streak', _longestStreak);
      }
      _prefs?.setInt('current_streak', _currentStreak);
      _prefs?.setBool('streak_increased_today', false);
      FirebaseCrashlytics.instance.setCustomKey(
        'current_streak',
        _currentStreak,
      );
    }
    notifyListeners();
    _saveToCloud();
  }
  // --- LIST MANAGEMENT ---

  Future<void> addHabit(Habit newHabit) async {
    // Add to Firestore
    final docRef = await _db
        .collection('users')
        .doc(_userId)
        .collection('habits')
        .add(newHabit.toMap());

    // Add to local state
    _habits[docRef.id] = newHabit;
    notifyListeners();
  }

  /// Inserts or updates a habit in local state immediately and notifies
  /// listeners. Call this right after a direct Firestore write so the UI
  /// reflects the change without waiting for the next cold-load.
  void upsertHabitLocally(String docId, Habit habit) {
    _habits[docId] = habit;
    notifyListeners();
  }

  Future<void> removeHabit(String habitId) async {
    // onDeleteHabit (routine_card.dart) is a sync callback, so its caller
    // can't await or catch this -- without a try/catch here, a failed
    // delete (offline, etc.) was an unhandled Future rejection while the
    // UI had already shown a "Habit deleted" snackbar with an Undo action,
    // implying success regardless of whether Firestore agreed.
    try {
      // Remove from Firestore
      await _db
          .collection('users')
          .doc(_userId)
          .collection('habits')
          .doc(habitId)
          .delete();

      // Remove from local state
      _habits.remove(habitId);
      notifyListeners();
      NotificationService.cancelHabitReminder(habitId);
      // Otherwise the featured-habit widget would be left permanently
      // pointing at a habit that no longer exists.
      if (habitId == _featuredHabitId) {
        setFeaturedHabit(null);
      }
    } catch (e, stack) {
      debugPrint('Failed to remove habit $habitId: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'removeHabit failed',
      );
    }
  }

  /// Restores a previously deleted habit to both Firestore and local state
  Future<void> restoreHabit(Habit habit) async {
    // Add back to Firestore
    await _db
        .collection('users')
        .doc(_userId)
        .collection('habits')
        .doc(habit.id)
        .set(habit.toMap());

    // Add back to local state
    _habits[habit.id] = habit;
    _completedHabits[habit.id] = habit.isCompleted;
    NotificationService.scheduleHabitReminder(habit);

    _recentlyRestoredHabitIds.add(habit.id);
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 600), () {
      _recentlyRestoredHabitIds.remove(habit.id);
    });
  }

  Future<void> reorderHabits(
    String routineType,
    int oldIndex,
    int newIndex,
  ) async {
    // 1. Grab habits and update their order values locally
    List<Habit> routineHabits = getHabitsForRoutine(routineType);
    final Habit movedHabit = routineHabits.removeAt(oldIndex);
    routineHabits.insert(newIndex, movedHabit);

    // 2. Map new layout sequentially for Local Cache & Firestore
    final batch = _db.batch();
    final Map<String, int> orderMap = {};

    for (int i = 0; i < routineHabits.length; i++) {
      routineHabits[i].order = i;
      orderMap[routineHabits[i].id] = i;

      // Prepare Firestore sync
      final docRef = _db
          .collection('users')
          .doc(_userId)
          .collection('habits')
          .doc(routineHabits[i].id);
      batch.update(docRef, {'order': i});
    }

    notifyListeners(); // Refresh UI instantly

    // 3. Persist to local cache and Firestore seamlessly in the background
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('habit_order_$routineType', jsonEncode(orderMap));
    } catch (e) {
      debugPrint("Error caching reorder locally: $e");
    }
    try {
      // onReorder (routine_card.dart) is a sync callback, so its caller
      // can't await or catch this -- a failed commit here (offline, etc.)
      // was an unhandled Future rejection, and the in-memory order (already
      // applied above via notifyListeners()) silently reverts on the next
      // cold _loadData() with no explanation to the user.
      await batch.commit();
    } catch (e, stack) {
      debugPrint('Failed to persist habit reorder: $e');
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'reorderHabits batch commit failed',
      );
    }
  }

  // --- ONBOARDING PERSONALIZATION ---
  List<String> _morningHabits = [];
  List<String> _workHabits = [];
  List<String> _nightHabits = [];

  void setPersonalizedHabits(
    List<String> morning,
    List<String> work,
    List<String> night,
  ) {
    _morningHabits = morning;
    _workHabits = work;
    _nightHabits = night;

    _completedHabits.clear();
    for (var h in [..._morningHabits, ..._workHabits, ..._nightHabits]) {
      _completedHabits[h] = false;
    }
    notifyListeners();
    _saveToCloud();
  }

  Future<void> setDailyIntention(String? intention) async {
    _dailyIntention = intention;
    notifyListeners();

    if (_prefs != null) {
      if (intention != null && intention.isNotEmpty) {
        await _prefs!.setString('daily_intention', intention);
        String today = DateTime.now().toIso8601String().substring(0, 10);
        _intentionHistory[today] = intention;
      } else {
        await _prefs!.remove('daily_intention');
      }
    }
    _saveToCloud();
  }

  Future<void> deleteIntentionEntry(String dateStr) async {
    _intentionHistory.remove(dateStr);

    String today = DateTime.now().toIso8601String().substring(0, 10);
    if (dateStr == today) {
      _dailyIntention = null;
      if (_prefs != null) await _prefs!.remove('daily_intention');
    }
    notifyListeners();
    _saveToCloud();
  }

  Future<void> logMood(String mood, String note) async {
    _todaysMood = mood;
    _todaysNote = note;

    String today = DateTime.now().toIso8601String().substring(0, 10);
    _moodHistory[today] = {'mood': mood, 'note': note};

    notifyListeners();
    if (_prefs != null) {
      await _prefs!.setString('todays_mood', mood);
      await _prefs!.setString('todays_note', note);
    }
    _saveToCloud();
  }

  Future<void> deleteMoodEntry(String dateStr) async {
    _moodHistory.remove(dateStr);

    String today = DateTime.now().toIso8601String().substring(0, 10);
    if (dateStr == today) {
      _todaysMood = null;
      _todaysNote = null;
      if (_prefs != null) {
        await _prefs!.remove('todays_mood');
        await _prefs!.remove('todays_note');
      }
    }
    notifyListeners();
    _saveToCloud();
  }

  Future<void> refreshData() async {
    // This public method allows UI to trigger a data refresh from the cloud.
    await _loadData();
  }

  Future<void> resetAllProgressAndHabits({
    bool clearNotifications = false,
  }) async {
    _currentStreak = 0;
    _longestStreak = 0;
    _totalHabitsCompleted = 0;
    _totalHabitsAssigned = 0;
    _prefs?.setInt('total_habits_completed', 0);
    _unlockedJourneyChapters.clear();
    _moodHistory.clear();
    _intentionHistory.clear();
    _completedHabits.clear();
    _habits.clear();
    _interests.clear();
    _xp = 0;
    _xpHistory.clear();
    _activeNebulaTheme = 'Default';

    // Purge all OS-level scheduled alarms so ghosts don't haunt the fresh reset
    NotificationService.cancelAlarms('Morning');
    NotificationService.cancelAlarms('Work');
    NotificationService.cancelAlarms('Night');
    NotificationService.cancelAlarm(999); // Clear Daily Reminder too

    if (_prefs != null) {
      await _prefs!.remove('current_streak');
      await _prefs!.remove('longest_streak');
      await _prefs!.remove('weekly_progress_history');
      await _prefs!.remove('active_nebula_theme');
      await _prefs!.remove('xp');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final batch = _db.batch();
      final habitsSnap = await _db
          .collection('users')
          .doc(user.uid)
          .collection('habits')
          .get();
      for (var doc in habitsSnap.docs) {
        batch.delete(doc.reference);
      }

      if (clearNotifications) {
        final notificationsSnap = await _db
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .get();
        for (var doc in notificationsSnap.docs) {
          batch.delete(doc.reference);
        }
      }

      // Remove the interests array from the user's document
      batch.update(_db.collection('users').doc(user.uid), {
        'interests': FieldValue.delete(),
      });

      await batch.commit();
    }

    notifyListeners();
    await _saveToCloud();
  }

  // Despite CLAUDE.md's description, this previously fired a full ~25-field
  // document write on *every* call with no coalescing -- rapid habit
  // toggles/count taps each dispatched their own back-to-back Firestore
  // write. All ~25 call sites just fire-and-forget `_saveToCloud();`
  // (bar one `await`), so debouncing here needs no call-site changes:
  // repeated calls within the window share the same pending Completer and
  // resolve together once the coalesced write actually happens.
  Timer? _saveDebounceTimer;
  Completer<void>? _saveDebounceCompleter;

  Future<void> _saveToCloud() {
    _saveDebounceTimer?.cancel();
    final completer = _saveDebounceCompleter ??= Completer<void>();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 800), () async {
      _saveDebounceCompleter = null;
      try {
        await _saveToCloudNow();
        if (!completer.isCompleted) completer.complete();
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });
    return completer.future;
  }

  Future<void> _saveToCloudNow() async {
    try {
      // Convert _routineAlarms to a format Firestore understands
      Map<String, dynamic> alarmsData = {};
      _routineAlarms.forEach((key, value) {
        alarmsData[key] = value.map((e) => e.toMap()).toList();
      });

      await _db.collection('users').doc(_userId).set({
        'routine_rewards': _routineRewards,
        'routine_alarms': alarmsData,
        'habits': _completedHabits,
        'current_streak': _currentStreak,
        'streak_increased_today': _hasIncreasedStreakToday,
        'streakFreezes': _streakFreezes,
        'isStreakFrozen': _isStreakFrozen,
        'longest_streak': _longestStreak,
        'total_habits_assigned': _totalHabitsAssigned,
        'total_habits_completed': _totalHabitsCompleted,
        'xp': _xp,
        'xp_history': _xpHistory,
        'avatar': _selectedAvatar,
        'mood_history': _moodHistory,
        'displayName':
            FirebaseAuth.instance.currentUser?.displayName ?? 'Commander',
        'intention_history': _intentionHistory,
        'unlocked_journey_chapters': _unlockedJourneyChapters,
        'audio_track': _selectedAudioTrack,
        'ambient_volume': _ambientVolume,
        'last_updated': FieldValue.serverTimestamp(),
        'bookmarked_quotes': _bookmarkedQuotes,
        'unlocked_reader_badge': _unlockedReaderBadge,
        'unlocked_themes': _unlockedThemes,
        'active_nebula_theme': _activeNebulaTheme,
        'all_notifs': _allNotifsEnabled,
        'daily_summary_notifs': _dailySummaryNotifs,
        'morning_notifs': _morningNotifs,
        'night_notifs': _nightNotifs,
        'fairy_taps': _fairyTaps,
        'unlocked_fairy_badge': _unlockedFairyBadge,
      }, SetOptions(merge: true));

      // --- OFFLINE CACHE: SAVE HABITS LOCALLY ---
      if (_prefs != null) {
        final habitsList = _habits.values.map((h) {
          final map = h.toMap();
          map['isCompleted'] = _completedHabits[h.id] ?? h.isCompleted;
          return map;
        }).toList();
        await _prefs!.setString('cached_habits_data', jsonEncode(habitsList));
      }

      //_updateHomeWidget();
    } catch (e, stack) {
      debugPrint("Failed to save to cloud: $e");
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Habit cloud sync failed during save',
      );
    }
  }

  // --- NATIVE HOME WIDGET SYNC ---
  Future<void> _updateHomeWidget() async {
    try {
      // Save the data to the native Key-Value store
      await HomeWidget.saveWidgetData<String>(
        'widget_streak',
        '$_currentStreak',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_intention',
        _dailyIntention ?? 'Set an intention today.',
      );

      // Tell the native OS to refresh the widget UI.
      // androidName must match the AppWidgetProvider class name registered in
      // AndroidManifest.xml — the plugin prepends the package ID automatically,
      // so use only the simple class name (not the fully-qualified name).
      await HomeWidget.updateWidget(
        androidName: 'OrbitWidget',
        iOSName: 'OrbitWidget',
      );
    } catch (e) {
      debugPrint('Error updating home screen widget: $e');
    }
  }

  /// Pins [habitId] to the "Habit Widget" home-screen widget, or clears it
  /// when null. A direct targeted write (like setInterests), not the big
  /// debounced _saveToCloud() -- merge writes only *preserve* fields
  /// they omit, they don't delete them, so clearing the selection needs
  /// an explicit FieldValue.delete() rather than just leaving the key out
  /// of a future save.
  Future<String?> setFeaturedHabit(String? habitId) async {
    final previous = _featuredHabitId;
    _featuredHabitId = habitId;
    notifyListeners();
    _updateFeaturedHabitWidget();
    try {
      if (habitId == null) {
        await _prefs?.remove('featured_habit_id');
      } else {
        await _prefs?.setString('featured_habit_id', habitId);
      }
      await _db.collection('users').doc(_userId).update({
        'featured_habit_id': habitId ?? FieldValue.delete(),
      });
      return null;
    } catch (e) {
      debugPrint('Failed to save featured habit: $e');
      _featuredHabitId = previous;
      notifyListeners();
      _updateFeaturedHabitWidget();
      return 'Could not save your featured habit. Please try again.';
    }
  }

  Future<void> _updateFeaturedHabitWidget() async {
    try {
      final habit = _featuredHabitId == null
          ? null
          : _habits[_featuredHabitId];
      await HomeWidget.saveWidgetData<String>(
        'title',
        habit?.title ?? 'Pick a habit in Settings',
      );
      await HomeWidget.saveWidgetData<int>(
        'streak',
        habit?.computeCurrentStreak() ?? 0,
      );
      await HomeWidget.updateWidget(
        androidName: 'HabitWidget',
        iOSName: 'HabitWidget',
      );
    } catch (e) {
      debugPrint('Error updating habit widget: $e');
    }
  }

  // Low power mode
  Future<void> toggleLowPowerMode() async {
    _lowPowerMode = !_lowPowerMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lowPowerMode', _lowPowerMode);
  }

  bool get lowPowerMode => _lowPowerMode;
}
