import 'dart:async';

/// Model-fallback for Gemini calls.
///
/// Since the July 2026 capacity crunch, `gemini-flash-latest` intermittently
/// returns 503 "high demand" or takes 10s+ per reply while the lite models
/// answer in under a second. Rather than pinning the app to whichever model
/// happens to be healthy today, every one-shot generation runs through
/// [withFallback]: best model first, sliding down the chain on
/// capacity-shaped failures (503/429/timeouts) while real errors (bad key,
/// blocked project, malformed request) still surface immediately.
class GeminiGateway {
  GeminiGateway._();

  static const List<String> modelChain = [
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-2.5-flash-lite',
  ];

  /// Per-model attempt budget. Long enough for a congested-but-working
  /// model to answer, short enough that falling through the whole chain
  /// stays tolerable in the UI.
  static const Duration attemptTimeout = Duration(seconds: 20);

  static bool _isCapacityError(Object e) {
    if (e is TimeoutException) return true;
    final msg = e.toString();
    return msg.contains('503') ||
        msg.contains('UNAVAILABLE') ||
        msg.contains('high demand') ||
        msg.contains('overloaded') ||
        msg.contains('Resource has been exhausted') ||
        msg.contains('429');
  }

  /// Runs [attempt] with each model name in [modelChain] until one
  /// succeeds. The callback constructs its own GenerativeModel so every
  /// call keeps its specific system instruction / generation config.
  static Future<T> withFallback<T>(
    Future<T> Function(String modelName) attempt,
  ) async {
    Object lastError = TimeoutException('No Gemini model responded');
    for (final name in modelChain) {
      try {
        return await attempt(name).timeout(attemptTimeout);
      } catch (e) {
        if (!_isCapacityError(e)) rethrow;
        lastError = e;
      }
    }
    throw lastError; // ignore: only_throw_errors
  }
}
