import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class CosmicMirrorService {
  late final GenerativeModel _model;

  CosmicMirrorService() {
    // 1. Securely fetch the key from your .env file
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";

    // 2. Initialize Gemini 1.5 Flash with a System Instruction
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      // This replaces the OpenAI "system" role message
      systemInstruction: Content.system(
        "You are the Cosmic Mirror, a mystical in-app narrator for a habit tracker called Orbit. "
        "You speak like an ancient oracle reading the stars.",
      ),
    );
  }

  Future<String> generateWeeklyLegend(
    List<String> habitsDone,
    List<String> habitsMissed,
  ) async {
    // Fallback in case there are no habits at all
    if (habitsDone.isEmpty && habitsMissed.isEmpty) {
      return "The stars are quiet. Begin your journey to forge a new constellation.";
    }

    // 3. The Prompt (Your awesome original prompt!)
    final prompt =
        '''
    The user successfully completed these habits: ${habitsDone.join(', ')}.
    The user struggled with these habits: ${habitsMissed.join(', ')}.
    
    Write a 3-sentence epic, mythic legend about their week. Use cosmic, celestial, and heroic metaphors. 
    Acknowledge their triumphs, and frame their struggles as a dark nebula they will conquer next time. 
    Do not use generic AI responses, make it sound ancient and prophetic.
    ''';

    try {
      // 4. Ask Gemini for the legend
      final response = await _model.generateContent([Content.text(prompt)]);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim();
      } else {
        return _getFallbackLegend();
      }
    } catch (e) {
      debugPrint('Error fetching Gemini legend: $e');
      return _getFallbackLegend();
    }
  }

  String _getFallbackLegend() {
    return "A bright light pierces the cosmic veil. Though the universe is vast, your efforts this week have forged new stars in the darkness. Keep pushing forward.";
  }

  // lib/services/cosmic_mirror_service.dart

  Future<String> generateDailyReflectionPrompt(
    List<String> habitsDone,
    List<String> habitsMissed,
  ) async {
    if (habitsDone.isEmpty && habitsMissed.isEmpty) {
      return "The void is completely still tonight. You built no stars today, but the expanse is waiting. What is the single smallest action you can take to spark a flame tomorrow?";
    }

    final prompt =
        '''
  Today, the user successfully completed these habits: ${habitsDone.join(', ')}.
  They struggled/missed these habits: ${habitsMissed.join(', ')}.
  
  Act as a mystical analytical oracle. Write exactly ONE deeply reflective, high-value psychological prompt (maximum 2 sentences).
  Acknowledge what went right, but explicitly ask them a deep question about the friction or roadblock that prevented them from finishing the missed habits.
  Do not use generic AI intro phrasing. Make it sound ancient, cryptic, yet highly actionable.
  ''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim();
      }
      return "Your constellations show division today. Reflect on what pulled your energy away from your alignment.";
    } catch (e) {
      debugPrint('Error generating reflection prompt: $e');
      return "The cosmic winds are turbulent. Look closely at your path tonight: where did your focus wander?";
    }
  }

  Future<String> generateCoachingMessage(String nodeId) async {
    // This prompt is a "meta-prompt" that asks Gemini to act as a prompt generator
    // for our specific coaching nodes. It's a powerful pattern.
    final prompt =
        '''
    You are the Cosmic Mirror, a mystical in-app narrator for a habit tracker called Orbit. 
    You speak like an ancient oracle reading the stars.

    Based on the following coaching node ID, generate a single, deeply insightful, and inspiring message (2-3 sentences).
    Do not use generic AI intro phrasing. Make it sound ancient, prophetic, and unique every time.

    Node ID: "$nodeId"

    Here are some hints for the tone of each node:
    - 'mental_dynamic': Focus on mental clarity, resilience, and the mind as a universe.
    - 'focus_dynamic': Use metaphors of light, lenses, and signal vs. noise for attention.
    - 'meditation_dynamic': Talk about stillness, cosmic resets, and inner silence.
    - 'exercise_dynamic': Use metaphors of rocket fuel, physical force, and recalibrating chemistry.
    - 'workout_dynamic': Emphasize absolute presence, physical limits, and mental clarity through exertion.
    - 'fact_dynamic': Provide a surprising psychological or scientific fact related to well-being, framed in a cosmic way.
    - 'not_sure_dynamic': Be gentle and encouraging, suggesting small experiments to find clarity.
    - 'done_dynamic': A concluding, anchoring statement that locks in the user's intention for the day/night.
    - 'input_dynamic': A question to prompt the user for their core intention.

    Generate the message now.
    ''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim();
      }
      return "The stars are aligning... what path will you choose?";
    } catch (e) {
      debugPrint('Error generating coaching message: $e');
      return "The cosmic frequency is distorted. Breathe, and we shall try again.";
    }
  }

  Future<String> generateRoutineGenieGreeting() async {
    const prompt = '''
    You are the Cosmic Mirror, a mystical in-app narrator for a habit tracker called Orbit.
    You are about to interact with the user in the "Routine Genie" feature, where they will state a goal and you will build a habit plan for them.

    Generate a single, welcoming, and mystical greeting (2-3 sentences).
    Invite the user to state their ultimate objective or desire.
    Make it sound ancient, prophetic, and unique every time. Do not use generic AI intro phrasing.

    Example tones: "The celestial loom awaits your thread...", "Speak your ambition into the void...", "I am listening to the echoes of your potential..."

    Generate the greeting now.
    ''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim();
      }
    } catch (e) {
      debugPrint('Error generating genie greeting: $e');
    }
    return "The celestial loom awaits. What destiny shall we weave?";
  }
}
