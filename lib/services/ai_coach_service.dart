import 'package:google_generative_ai/google_generative_ai.dart';
import 'gemini_gateway.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

class AiCoachService {
  static Future<String> generateGreeting() async {
    try {
      // 1. Fetch your key
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";

      // 2. Initialize Gemini (using the latest stable flash model)
      GenerativeModel buildModel(String m) => GenerativeModel(
        model: m,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
        systemInstruction: Content.system(
          "You are an AI Fairy and Cosmic Guide inside a habit tracker called Orbit. "
          "Keep your response strictly under 2 sentences.",
        ),
      );

      // 3. The Prompt
      const prompt =
          "Give the user a short, highly motivational, and cosmic-themed welcome message to ignite their productivity today.";

      final response = await GeminiGateway.withFallback(
        (m) => buildModel(m).generateContent([Content.text(prompt)]),
      );
      return response.text?.trim() ??
          "The stars are quiet today. Forge your own path!";
    } catch (e) {
      debugPrint('Error generating greeting: $e');
      return "The cosmic connection is weak, but your potential is infinite. Keep pushing!";
    }
  }

  // A tiny stable signature so cached AI output regenerates when the
  // user edits their Focus Interests (String.hashCode isn't guaranteed
  // stable across sessions, so sum code units instead).
  static String _interestsSignature(List<String>? interests) {
    if (interests == null || interests.isEmpty) return '0';
    final joined = interests.join(',');
    var sum = 0;
    for (final c in joined.codeUnits) {
      sum = (sum + c) % 100000;
    }
    return '${interests.length}_$sum';
  }

  static String _interestsContext(List<String>? interests) {
    if (interests == null || interests.isEmpty) return '';
    return 'The user cares most about these focus areas: ${interests.join(", ")}. When natural, angle the message toward one of them.';
  }

  static Future<String> generateInsight({
    required int completedCount,
    required int totalHabits,
    required int currentStreak,
    List<String>? recentSkipReasons,
    List<String>? interests,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return "${_getFallbackInsight(completedCount, totalHabits)} (Sign in to get personalized insights!)";
    }

    // 1. Create a unique hash for today's state
    final today = DateTime.now().toIso8601String().split('T')[0];
    final stateKey =
        "${today}_${completedCount}_${totalHabits}_${_interestsSignature(interests)}";

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cache')
        .doc('ai_insight');

    try {
      // 2. Try to fetch from cache first (Firestore checks local cache automatically)
      final doc = await docRef.get();
      if (doc.exists && doc.data()?['stateKey'] == stateKey) {
        return doc.data()!['insight'] as String;
      }

      // 3. Cache Miss: Generate a new insight via Gemini
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return _getFallbackInsight(completedCount, totalHabits);
      }

      GenerativeModel buildModel(String m) =>
          GenerativeModel(model: m, apiKey: apiKey);

      String skipContext = '';
      if (recentSkipReasons != null && recentSkipReasons.isNotEmpty) {
        skipContext =
            'Recently, the user skipped sessions because: ${recentSkipReasons.join(", ")}. If appropriate, gently and encouragingly reference this to help them overcome it.';
      }

      final prompt =
          '''
You are an AI habit coach inside a space-themed habit tracking app.
Your user has completed $completedCount out of $totalHabits habits today, and their current streak is $currentStreak days.
$skipContext
${_interestsContext(interests)}
Write a short, encouraging, 1-2 sentence message to motivate them. Keep it space-themed and actionable!
      ''';

      final response = await GeminiGateway.withFallback(
        (m) => buildModel(m).generateContent([Content.text(prompt)]),
      );
      final newInsight =
          response.text?.replaceAll(RegExp(r'\n+'), ' ').trim() ??
          _getFallbackInsight(completedCount, totalHabits);

      // 4. Save the new insight to Firestore for future cache hits
      await docRef.set({
        'stateKey': stateKey,
        'insight': newInsight,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return newInsight;
    } catch (e) {
      debugPrint('AI Coach Error: (likely offline) $e');

      // OFFLINE FALLBACK: Try to fetch the last known insight from local cache
      try {
        final fallbackDoc = await docRef.get(
          const GetOptions(source: Source.cache),
        );
        if (fallbackDoc.exists && fallbackDoc.data()?['insight'] != null) {
          return fallbackDoc.data()!['insight'] as String;
        }
      } catch (cacheError) {
        debugPrint('Cache retrieval failed: $cacheError');
      }

      // Ultimate fallback if both network and cache fail
      return _getFallbackInsight(completedCount, totalHabits);
    }
  }

  static Future<String> generateDailyIntention({
    String? latestSkipReason,
    List<String>? interests,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Master your day.';

    // 1. Create a unique hash for today's state
    final today = DateTime.now().toIso8601String().split('T')[0];
    final stateKey =
        "${today}_${latestSkipReason ?? 'none'}_${_interestsSignature(interests)}";

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cache')
        .doc('daily_intention');

    try {
      // 2. Try to fetch from cache first
      final doc = await docRef.get();
      if (doc.exists && doc.data()?['stateKey'] == stateKey) {
        return doc.data()!['intention'] as String;
      }

      // 3. Cache Miss: Generate a new intention via Gemini
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return 'Master your day.';
      }

      GenerativeModel buildModel(String m) =>
          GenerativeModel(model: m, apiKey: apiKey);

      String skipContext = '';
      if (latestSkipReason != null && latestSkipReason.isNotEmpty) {
        skipContext =
            'The user recently skipped a habit because: "$latestSkipReason". Make this intention directly inspire them to overcome this specific hurdle today.';
      }

      final prompt =
          '''
You are a cosmic AI coach. Generate a short, highly inspiring, space-themed daily intention (maximum 6 words) for the user.
$skipContext
${_interestsContext(interests)}
Examples: "Embrace the stellar unknown.", "Command your orbit today.", "Shine brighter than supernovas."
Do not include quotes around the text.
      ''';

      final response = await GeminiGateway.withFallback(
        (m) => buildModel(m).generateContent([Content.text(prompt)]),
      );
      final newIntention =
          response.text?.replaceAll('"', '').trim() ?? 'Master your day.';

      // 4. Save to Firestore cache
      await docRef.set({
        'stateKey': stateKey,
        'intention': newIntention,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return newIntention;
    } catch (e) {
      debugPrint('AI Intention Error (likely offline): $e');

      // 5. OFFLINE FALLBACK
      try {
        final fallbackDoc = await docRef.get(
          const GetOptions(source: Source.cache),
        );
        if (fallbackDoc.exists && fallbackDoc.data()?['intention'] != null) {
          return fallbackDoc.data()!['intention'] as String;
        }
      } catch (cacheError) {
        debugPrint('Cache retrieval failed: $cacheError');
      }

      return 'Forge your own path.';
    }
  }

  static String _getFallbackInsight(int completedCount, int totalHabits) {
    if (completedCount == 0) {
      return 'Mission control is ready. Launch your first habit today!';
    }
    if (completedCount == totalHabits && totalHabits > 0) {
      return 'All systems go! Flawless execution today, Commander.';
    }
    return 'Orbit stabilized. You are making great progress, keep pushing!';
  }

  static Future<Map<String, String>> analyzeImageForHabit(
    XFile imageFile,
  ) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
      GenerativeModel buildModel(String m) =>
          GenerativeModel(model: m, apiKey: apiKey);
      final bytes = await File(imageFile.path).readAsBytes();

      final prompt = TextPart(
        "Analyze this image. Suggest ONE healthy daily habit based on the object in the image. Return ONLY a JSON string with three keys: 'title' (short habit name), 'icon' (pick one: Explore, Fitness, Book, Mind, Sun, Moon, Work), and 'description' (a 1 sentence motivational reason).",
      );
      final imagePart = DataPart('image/jpeg', bytes);

      final response = await GeminiGateway.withFallback(
        (m) => buildModel(m).generateContent([
          Content.multi([prompt, imagePart]),
        ]),
      );

      final responseText = response.text ?? "{}";
      final cleanJson = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;

      return {
        'title': decoded['title']?.toString() ?? 'Discover',
        'icon': decoded['icon']?.toString() ?? 'Explore',
        'description':
            decoded['description']?.toString() ?? 'Try something new today.',
      };
    } catch (e) {
      debugPrint('Vision API Error: $e');
      return {
        'title': 'Discover',
        'icon': 'Explore',
        'description': 'Try something new today.',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> generateConstellation(
    String goal,
  ) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
      if (apiKey.isEmpty) {
        throw Exception("API key is blank inside environment targets.");
      }

      GenerativeModel buildModel(String m) => GenerativeModel(
        model: m,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      // We explicitly instruct Gemini to return a root dictionary object containing our tracking key
      final prompt =
          """
      The user wants to achieve this goal: "$goal". 
      Create a 4-week habit roadmap called a "Constellation".
      Provide exactly 4 specific habits, one for each week, that escalate sequentially in difficulty.
      
      Crucial UI Rule: You MUST assign a different, unique 'icon' string value for each of the 4 weeks. 
      Mix and match cleanly between 'Mind', 'Fitness', 'Explore', and 'Book'. Do not repeat icons.

      Also assign each habit a 'routine' — the time of day it fits best:
      'Morning', 'Work', or 'Night'.

      You must return a JSON object with a single root key named "habits" containing the array list:
      {
        "habits": [
          {"week": 1, "habitTitle": "Short Title", "icon": "Mind", "routine": "Morning", "description": "1 sentence why"},
          {"week": 2, "habitTitle": "Short Title", "icon": "Fitness", "routine": "Work", "description": "1 sentence why"},
          {"week": 3, "habitTitle": "Short Title", "icon": "Explore", "routine": "Night", "description": "1 sentence why"},
          {"week": 4, "habitTitle": "Short Title", "icon": "Book", "routine": "Morning", "description": "1 sentence why"}
        ]
      }
      """;

      debugPrint(
        "📡 GEMINI API CALL: Pinging model gateway using query payload...",
      );
      final response = await GeminiGateway.withFallback(
        (m) => buildModel(m).generateContent([Content.text(prompt)]),
      );

      final String? responseText = response.text;
      if (responseText == null || responseText.isEmpty) {
        throw Exception(
          "Gemini server nodes returned an empty payload stream.",
        );
      }

      debugPrint(
        "📥 GEMINI RESPONSE RECEIVED: De-serializing constellation map packet...",
      );
      final Map<String, dynamic> decodedObject =
          jsonDecode(responseText.trim()) as Map<String, dynamic>;

      // Extract the nested list out safely past the dictionary envelope wrapper
      final List<dynamic>? habitList =
          decodedObject['habits'] as List<dynamic>?;

      if (habitList != null) {
        return List<Map<String, dynamic>>.from(habitList);
      } else {
        throw const FormatException(
          "Returned JSON payload was missing the mandatory 'habits' list key index.",
        );
      }
    } catch (e) {
      debugPrint(
        "💥 ENGINE FAILURE INSIDE AICOACHSERVICE GENERATE_CONSTELLATION: $e",
      );
      rethrow;
    }
  }

  static Future<String> generateProAlignmentScan(
    List<Map<String, dynamic>> activeHabits,
  ) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
      GenerativeModel buildModel(String m) =>
          GenerativeModel(model: m, apiKey: apiKey);

      final habitsSummary = activeHabits
          .map(
            (h) =>
                "- ${h['title']} (${h['completedDays']}/${h['totalDays']} days completed)",
          )
          .join("\n");

      final prompt =
          """
      You are the Orbit AI Mission Commander. Analyze the user's current payload of habits:
      $habitsSummary

      Provide a hyper-focused, tactical evaluation of their routine strategy. 
      Identify the weakest link or potential friction points and give exactly ONE actionable, space-themed optimization directive.
      Keep it strictly under 3 sentences. Be authoritative, motivating, and sharp.
      """;

      final response = await GeminiGateway.withFallback(
        (m) => buildModel(m).generateContent([Content.text(prompt)]),
      );
      return response.text?.trim() ??
          "Telemetry link weak. Continue tracking your trajectory.";
    } catch (e) {
      debugPrint("💥 Pro Scan Error: $e");
      return "Cosmic static detected. Your trajectory is solid—continue your mission.";
    }
  }

  // Future<void> saveConstellation(String goal, List<Map<String, dynamic>> constellation) async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) return;

  //   await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(user.uid)
  //       .collection('constellations')
  //       .add({
  //     'goal': goal,
  //     'constellation': constellation,
  //     'createdAt': FieldValue.serverTimestamp(),
  //     }); } catch (e) {
  //     debugPrint("Error saving constellation: $e");
  //     // Handle error as needed, e.g., show a message to the user or log it for analytics.
  //     }
}
