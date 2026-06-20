import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    await _flutterTts.setSharedInstance(true);

    // Configure for a smooth, premium pacing
    await _flutterTts
        .setSpeechRate(0.45); // Slightly slower for a calming effect
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.1); // Slightly higher pitch for a "Fairy" vibe

    // Try to find a premium English voice (this varies by device, but we ask for a good default)
    await _flutterTts.setLanguage("en-US");

    _isInitialized = true;
  }

  static Future<void> speak(String text) async {
    if (!_isInitialized) await init();

    // Stop any current speech before starting new
    await _flutterTts.stop();

    // Optional: Clean up text (remove emojis or markdown that sounds weird when spoken out loud)
    String cleanText = text.replaceAll(RegExp(r'[*_~]'), '');

    await _flutterTts.speak(cleanText);
  }

  static Future<void> stop() async {
    await _flutterTts.stop();
  }
}
