import 'package:flutter/material.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  
  String? _currentUrl;
  String? _currentTitle;
  String? _currentSubtitle;
  String? _currentArtUrl;

  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;

  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get duration => _duration;
  Duration get position => _position;
  String? get currentUrl => _currentUrl;
  String? get currentTitle => _currentTitle;
  String? get currentSubtitle => _currentSubtitle;
  String? get currentArtUrl => _currentArtUrl;
  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;

  AudioProvider() {
    _positionSubscription = _audioPlayer.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _durationSubscription = _audioPlayer.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == ProcessingState.buffering || state.processingState == ProcessingState.loading;
      
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _position = Duration.zero;
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> play(String url, {String? title, String? subtitle, String? artUrl}) async {
    if (_currentUrl != url) {
      _currentUrl = url;
      _currentTitle = title ?? _currentTitle;
      _currentSubtitle = subtitle ?? _currentSubtitle;
      _currentArtUrl = artUrl ?? _currentArtUrl;
      
      // Provide metadata to the lock-screen!
      final mediaItem = MediaItem(
        id: url,
        album: 'Orbit Coaching',
        title: _currentTitle ?? 'Audio',
        artist: _currentSubtitle ?? 'Orbit AI',
        artUri: Uri.parse(_currentArtUrl ?? 'https://images.unsplash.com/photo-1444703686981-a3abbc4d4fe3?q=80&w=1000&auto=format&fit=crop'), // Fallback to your gorgeous contract background!
      );

      if (url.startsWith('http')) {
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url), tag: mediaItem));
      } else {
        // just_audio expects local assets to explicitly start with "assets/"
        await _audioPlayer.setAudioSource(AudioSource.asset('assets/$url', tag: mediaItem));
      }
    }
    await _audioPlayer.play();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // --- SLEEP TIMER LOGIC ---
  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimerRemaining = duration;
    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerRemaining != null && _sleepTimerRemaining!.inSeconds > 0) {
        _sleepTimerRemaining = _sleepTimerRemaining! - const Duration(seconds: 1);
        notifyListeners();
      } else {
        pause();
        cancelSleepTimer();
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerRemaining = null;
    notifyListeners();
  }
}