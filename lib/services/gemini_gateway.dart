import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';

/// Proxy for every Gemini call the app makes.
///
/// GEMINI_API_KEY used to live in a bundled .env asset and be used directly
/// by GenerativeModel(apiKey: ...) client-side -- which means it shipped in
/// plaintext inside every app binary, extractable by anyone who downloaded
/// the app. That's how the backing Google Cloud project ended up suspended
/// for "abusive activity consistent with hijacking": the key was harvested
/// straight out of a public build. Every call now goes through the
/// generateWithGemini Cloud Function instead, which holds the key server-side
/// (Secret Manager) and walks the same 3-model capacity-fallback chain this
/// class used to run client-side.
class GeminiGateway {
  GeminiGateway._();

  static Future<String> generate({
    required String prompt,
    String? systemInstruction,
    bool jsonMode = false,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable(
          'generateWithGemini',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
        );

    final result = await callable.call<Map<String, dynamic>>({
      'prompt': prompt,
      if (systemInstruction != null) 'systemInstruction': systemInstruction,
      if (jsonMode) 'jsonMode': true,
      if (imageBytes != null && imageMimeType != null)
        'imageBase64': base64Encode(imageBytes),
      if (imageBytes != null && imageMimeType != null)
        'imageMimeType': imageMimeType,
    });

    final text = result.data['text'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('Empty response from generateWithGemini');
    }
    return text;
  }
}
