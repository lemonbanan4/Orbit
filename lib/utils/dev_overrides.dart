import 'package:flutter/foundation.dart';

/// Development-only switches.
///
/// [forceProInDebug] unlocks every "Orbit Pro" gate while running a debug
/// build (`flutter run`), so paywalled features can be exercised without a
/// sandbox purchase. It is gated on [kDebugMode], so release/TestFlight/App
/// Store builds ignore it completely no matter what it's set to — there is
/// no way for this to leak past App Review.
class DevOverrides {
  DevOverrides._();

  /// Flip to false to test the real paywall flow in debug builds.
  static const bool forceProInDebug = true;

  static bool get isProUnlocked => kDebugMode && forceProInDebug;

  /// Flip to false to test the real Orbit Store XP costs (streak freezes,
  /// Nebula Themes) in debug builds.
  static const bool freeStoreInDebug = true;

  static bool get storeIsFreeInDebug => kDebugMode && freeStoreInDebug;
}
