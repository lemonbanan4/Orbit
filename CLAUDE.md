# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Orbit (package name `orbit_app`) is a Flutter mobile app for habit/routine tracking with gamification
(streaks, XP, journey milestones), an AI coach, ambient audio, and a RevenueCat paywall. Backend is
Firebase (Auth, Firestore, Cloud Functions, Storage, Messaging, Remote Config, Crashlytics, App Check).
iOS/Android are the primary targets; web/desktop builds exist but many features are gated behind
`kIsWeb`/`Platform.isIOS` checks (RevenueCat, HomeWidget, push notifications, native audio session setup).

## Commands

### Flutter app
```bash
flutter pub get                 # install dependencies
flutter run                     # run on a connected device/simulator
flutter analyze                 # static analysis (uses analysis_options.yaml + flutter_lints)
flutter test                    # run all widget/unit tests under test/
flutter test test/widget_test.dart   # run a single test file
flutter build ios / apk / appbundle  # release builds
```
Widget-image and notification-service tests live alongside their source in `lib/services/` (e.g.
`lib/services/notification_service_test.dart`), not just under `test/`.

### Cloud Functions (`functions/`, TypeScript)
```bash
cd functions
npm run build        # tsc compile to lib/
npm run lint         # eslint (google config)
npm test             # jest (ts-jest), runs *.test.ts
npm run serve        # build + start functions emulator
npm run shell        # build + firebase functions:shell
npm run deploy       # firebase deploy --only functions
```
`firebase.json` runs `lint` then `build` as `predeploy` steps, so both must pass before a deploy.

### Firestore security rules tests (root, JS/Jest)
```bash
firebase emulators:start --only firestore   # start emulator first (port 8080)
npx jest test/firestore.rules.test.js       # then run in a second terminal
```
These tests load `firestore.rules` directly via `@firebase/rules-unit-testing` against the local
emulator — they do not run against production and require the emulator to already be up.

### Firebase emulators
`firebase emulators:start` boots the full suite defined in `firebase.json` (`singleProjectMode`):
auth (9099), functions (5001), firestore (8080), database (9000), hosting (5005), pubsub (8085),
storage (9199), eventarc (9299), dataconnect (9399), tasks (9499), plus the emulator UI.
Firebase project id is `orbit-mvp-54642` (see `.firebaserc`).

## Architecture

### State management: one dominant provider
The app uses `provider` (ChangeNotifier), registered as a `MultiProvider` in `lib/main.dart`:
`RoutineProvider`, `AppAuthProvider`, `AIFairyProvider`, `AtmosphereProvider`, `TelemetryProvider`,
plus a plain `Provider<CosmicMirrorService>`.

`lib/providers/routine_provider.dart` (~1500 lines) is the de facto application state store —
essentially everything that isn't auth or AI-chat lives here: habits/routines, streaks, XP, daily
intentions, mood log, journey chapter/milestone unlocks, theme/notification/haptic settings, alarm
scheduling, and ambient audio playback (via both `audioplayers` and `just_audio`). It persists to
`SharedPreferences` for local/offline state and mirrors writes to Firestore through a debounced
`_saveToCloud()`. When there's no authenticated user it falls back to a hardcoded guest id
(`commander_001`) rather than blocking on auth — keep this in mind when touching auth-gated logic.
Most new user-facing state belongs as fields/methods on this provider unless it's clearly auth or
AI-chat scoped.

### Services vs. providers
`lib/services/` holds stateless/Firebase-facing logic that providers call into: `firestore_service`,
`auth_service`, `notification_service` (local notifications + FCM), `ai_coach_service` /
`ai_fairy_service` (AI coach, backed by `google_generative_ai`), `cosmic_mirror_service` (weekly
recap generation), `voice_service` (TTS/speech-to-text), `share_service`, `alchemy_telemetry_service`.
Providers own state and call services; services should stay free of ChangeNotifier/UI concerns.

### Screens
`lib/screens/` is organized by feature area, not by widget type: `onboarding/`, `navigation/`
(the shell — `main_navigation_screen.dart` is the real app shell with its own internal tab state),
`habits/`, `routines/`, `journey/`, `coaching/`, `sanctuary/`, `stats/`, `social/`, `paywall/`,
`settings/`, `videos/`, `common/`. Top-level routing (`go_router` in `lib/main.dart`) only defines a
handful of routes (`/`, `/profile`, `/journey`, `/habit`) used for deep links from push notifications
and the home-screen widget (`orbit://...` URIs); most in-app navigation happens via internal state in
`MainNavigationScreen` rather than named routes.

### Cloud Functions (`functions/src/index.ts`)
Single file (~1200 lines) containing all backend functions, grouped by trigger type:
- Firestore triggers: push notifications on new chat message, milestone unlock, friend request
  (sent/accepted), partner habit completion, partner link, streak-freeze consumption.
- Scheduled (`onSchedule`): weekly progress reset, stale-notification cleanup, daily summary push,
  orphaned guest account deletion, retention emails, inactive-account management.
- Callable (`onCall`): referral code redemption, streak-freeze purchase.
- HTTP (`onRequest`): RevenueCat webhook, email-open tracking pixel.
Data model matches `firestore.rules`: everything nests under `users/{userId}`, with
`habits/{habitId}`, `skipped_sessions/{sessionId}`, `notifications/{notificationId}` subcollections.

### Firestore security rules (`firestore.rules`)
Single-collection-root model (`users/{userId}`) with domain validator functions (`isValidUser`,
etc.) that allowlist exactly which top-level fields a client write may touch. When adding a new
field to the user document from the Flutter app, it must also be added to the corresponding
`allowedKeys`/validator in `firestore.rules` or writes will be silently rejected — update
`test/firestore.rules.test.js` alongside any rule change.

### iOS home-screen widgets
There are **two** parallel widget extension pairs in `ios/`: `HabitWidget`/`HabitWidgetExtension`
and `OrbitWidget`/`OrbitWidgetExtension`. These look like an in-progress rename/duplication rather
than two distinct features — check which target is actually wired into the active Xcode scheme
before editing widget Swift code or assets, so changes don't land in the unused copy. Widget data is
pushed from Dart via `home_widget` (`HomeWidget.saveWidgetData` / `updateWidget` in
`RoutineProvider._updateHomeWidget` and `main.dart`), and widget taps deep-link back into the app
through the `orbit://` scheme handled in `_OrbitAppState._handleWidgetNavigation`.

### Monetization & native integrations
RevenueCat (`purchases_flutter`) drives the paywall/entitlements (`"Orbit Pro"` entitlement),
initialized in `main.dart` and synced to Firebase Auth via `Purchases.logIn`/`logOut` on auth state
changes; the `revenueCatWebhook` Cloud Function handles server-side events. Crashlytics is wired to
capture both Flutter framework errors and `debugPrint` output (see the `debugPrint` override in
`main.dart`). Local notification scheduling and FCM token sync happen on every app boot and login.


## 🚀 Current Launch/App Store Strategy
- **Company Entity:** Orbit is a product of **CogCore LLC** (Wyoming).
- **Compliance Status:**
    - Privacy Policy/Terms must reflect CogCore LLC. https://orbitroutine/privcay.html, https://orbitroutine/terms.html
    - Standard Apple EULA link used: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- **Current Rejection Blockers:**
    - Guideline 2.1(b): IAP "Close" button functionality bug in sandbox.
    - Guideline 3.1.2(c): Missing subscription metadata in App Store description.
- **Immediate Priorities:**
    - IAP logic resides in lib/screens/paywall/paywall_screen.dart. Rejection fixed by adding _pollForEntitlement and _isVerifying state to handle sandbox lag.
    - Audit description to include Subscription Terms (Title, Length, Price, EULA link).
    - Ensure all legal URLs link to the CogCore LLC-verified policy.