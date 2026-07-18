import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:orbit_app/main.dart' as app;

/// Manual verification for the Nebula Theme feature: navigates the real,
/// running app (guest session) from Home -> Profile -> Settings -> the new
/// "Nebula Theme" tile, and pauses on each screen so a host-side
/// `xcrun simctl io booted screenshot` can capture it.
///
/// Uses fixed-duration `pump()` calls rather than `pumpAndSettle()` —
/// several screens run perpetual `flutter_animate` loops (glow orbs, the
/// AI fairy shimmer), so `pumpAndSettle` never finds a quiet frame and
/// hangs indefinitely.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navigate to Nebula Theme sheet', (tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 10));

    // Home screen — hold so it can be screenshotted.
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('Profile'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(seconds: 3));

    final settingsIcon = find.byIcon(Icons.settings_rounded);
    expect(settingsIcon, findsOneWidget);
    await tester.tap(settingsIcon);
    await tester.pump(const Duration(seconds: 3));

    final nebulaTile = find.text('Nebula Theme');
    await tester.scrollUntilVisible(nebulaTile, 200);
    await tester.pump(const Duration(milliseconds: 500));
    expect(nebulaTile, findsOneWidget);
    await tester.tap(nebulaTile);
    await tester.pump(const Duration(seconds: 2));

    // Nebula Theme sheet open — hold for a while so it can be screenshotted.
    await tester.pump(const Duration(seconds: 8));

    expect(find.text('Aurora'), findsOneWidget);
    expect(find.text('Solstice'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
  });
}
