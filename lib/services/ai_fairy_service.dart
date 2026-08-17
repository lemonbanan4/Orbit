import 'dart:convert';
import 'gemini_gateway.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// This is the "Data Model" - keep it outside the service class
class AIFairyResponse {
  final String text;
  final List<String> options;

  AIFairyResponse({required this.text, required this.options});
}

class AIFairyService {
  static const String _systemInstruction =
      "You are the Orbit AI Fairy. You are ethereal, wise, and encouraging. "
      "Your goal is to help users maintain their habits. Use celestial metaphors. "
      "Always respond in valid JSON format ONLY with keys 'text' and 'options'.";

  Future<AIFairyResponse> getFairyInteraction(
    String habitName, {
    int skippedCount = 0,
    int streak = 0,
  }) async {
    String skipContext = skippedCount > 0
        ? "The user missed or skipped this habit $skippedCount times recently, but finally completed it today! Acknowledge their return to the path and offer cosmic encouragement."
        : "The user is staying consistent on their path.";
    // The caller already knows the real streak (RoutineProvider) -- feed
    // it into the prompt rather than letting the model guess or generate
    // a generic line, so any streak the fairy mentions is actually true.
    String streakContext = streak > 1
        ? "Their current streak on this habit is $streak days -- you may reference this specific number if it fits naturally."
        : "";

    final prompt =
        """
      The user just looked at their habit: '$habitName'.
      $skipContext
      $streakContext
      Give them a mystical, encouraging 1-sentence message.
      Also, provide 3 short options (max 3 words each) for the user to reply with.
      Respond ONLY in this JSON format:
      {"text": "your message here", "options": ["option 1", "option 2", "option 3"]}
    """;

    try {
      final responseText = await GeminiGateway.generate(
        prompt: prompt,
        systemInstruction: _systemInstruction,
        jsonMode: true,
      );

      // We need to clean the response text because Gemini sometimes wraps JSON in markdown blocks like ```json
      final cleanJson = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final data = jsonDecode(cleanJson);

      return AIFairyResponse(
        text: data['text'] ?? "The cosmos whispers your success.",
        options: List<String>.from(
          data['options'] ?? ["Blessings", "Guided", "Onward"],
        ),
      );
    } catch (e) {
      // Fallback if the AI or JSON fails
      return AIFairyResponse(
        text: "The nebula is cloudy today, but your path remains clear.",
        options: ["I agree", "Show me more", "Peace"],
      );
    }
  }

  Future<void> saveInteraction(
    String contextStr,
    String fairyMessage,
    String userReply,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fairy_history')
          .add({
            'context': contextStr,
            'fairyMessage': fairyMessage,
            'userReply': userReply,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      // Called fire-and-forget from ai_fairy_section.dart (no await, no
      // caller-side error handling) — without this, a rejected write
      // becomes an unhandled Future error instead of a low-severity,
      // logged failure of a chat-history entry.
      debugPrint('Failed to save fairy interaction: $e');
    }
  }

}
