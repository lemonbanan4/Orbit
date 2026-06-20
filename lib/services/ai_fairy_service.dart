import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  late final GenerativeModel _model;

  AIFairyService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      systemInstruction: Content.system(
        "You are the Orbit AI Fairy. You are ethereal, wise, and encouraging. "
        "Your goal is to help users maintain their habits. Use celestial metaphors. "
        "Always respond in valid JSON format ONLY with keys 'text' and 'options'.",
      ),
    );
  }

  Future<AIFairyResponse> getFairyInteraction(
    String habitName, {
    int skippedCount = 0,
  }) async {
    String skipContext = skippedCount > 0
        ? "The user missed or skipped this habit $skippedCount times recently, but finally completed it today! Acknowledge their return to the path and offer cosmic encouragement."
        : "The user is staying consistent on their path.";

    final prompt =
        """
      The user just looked at their habit: '$habitName'. 
      $skipContext
      Give them a mystical, encouraging 1-sentence message.
      Also, provide 3 short options (max 3 words each) for the user to reply with.
      Respond ONLY in this JSON format:
      {"text": "your message here", "options": ["option 1", "option 2", "option 3"]}
    """;

    try {
      final response = await _model.generateContent([Content.text(prompt)]);

      // We need to clean the response text because Gemini sometimes wraps JSON in markdown blocks like ```json
      final cleanJson = response.text!
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
  }

  static Future<List<Map<String, dynamic>>> generateConstellation(
    String goal,
  ) async {
    try {
      // Using the flash model for speed
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      final prompt =
          """
    The user's goal is: "$goal". 
    Create a 4-week habit roadmap called a "Constellation".
    Provide exactly 4 habits, one for each week, that escalate in difficulty.
    
    Return ONLY a JSON list. No conversational text.
    Format:
    [
      {"week": 1, "habitTitle": "Short Title", "icon": "Fitness/Mind/Book/Explore", "description": "1 sentence why"},
      ...
    ]
    """;

      final response = await model.generateContent([Content.text(prompt)]);
      final String cleanJson = response.text!
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      return List<Map<String, dynamic>>.from(jsonDecode(cleanJson));
    } catch (e) {
      debugPrint("Genie Error: $e");
      // Fallback if AI fails
      return [
        {
          "week": 1,
          "habitTitle": "Begin the Path",
          "icon": "Explore",
          "description": "Take your first step toward $goal.",
        },
      ];
    }
  }
}
