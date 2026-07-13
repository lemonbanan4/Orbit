# Orbit

Orbit is a Flutter mobile app for habit and routine tracking, combining streaks, XP, and
journey-based milestones with an AI coach, ambient focus audio, and a subscription paywall.

## Features

- **Habit & routine tracking** — daily habits, routines, and intentions with streaks and XP
  progression
- **Journey system** — unlockable chapters and milestones that gamify long-term consistency
- **AI coach** — conversational coaching powered by Google's Generative AI
- **Ambient audio** — focus/sleep soundscapes with background playback
- **Mood & journaling** — daily mood logging and journal entries
- **Social** — friend requests, partner habits, and shared accountability
- **Home-screen widgets** — live habit/streak widgets on iOS
- **Push notifications** — local + FCM-driven reminders and daily summaries
- **Orbit Pro** — RevenueCat-powered subscription paywall and entitlements

## Tech stack

- **Client:** Flutter/Dart, `provider` for state management
- **Backend:** Firebase — Auth, Firestore, Cloud Functions, Storage, Cloud Messaging, Remote
  Config, App Check, Crashlytics, Analytics
- **Monetization:** RevenueCat (`purchases_flutter`)
- **AI:** `google_generative_ai`

## Architecture

- `lib/providers/routine_provider.dart` is the primary application state store — habits,
  streaks, XP, journey progress, settings, and ambient audio all live here. It persists to
  `SharedPreferences` and mirrors writes to Firestore.
- `lib/services/` holds stateless Firebase-facing logic (`firestore_service`, `auth_service`,
  `notification_service`, `ai_coach_service`, `cosmic_mirror_service`, `voice_service`, etc.)
  that providers call into.
- `lib/screens/` is organized by feature area (`onboarding/`, `habits/`, `routines/`, `journey/`,
  `coaching/`, `sanctuary/`, `stats/`, `social/`, `paywall/`, `settings/`). Most in-app navigation
  is handled by internal state in `MainNavigationScreen`; `go_router` only covers a few deep-link
  routes.
- `functions/` contains the Cloud Functions backend (TypeScript) — Firestore triggers, scheduled
  jobs, callables, and HTTP endpoints (including the RevenueCat webhook).
- `firestore.rules` defines a single-collection-root data model (`users/{userId}`) with validator
  functions that allowlist which fields a client write may touch.

## Getting started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (SDK `>=3.44.0`, Dart `^3.12.0`)
- A Firebase project (see `.firebaserc`) with Auth, Firestore, Functions, Storage, and Messaging
  enabled
- Xcode (for iOS) and/or Android Studio (for Android)
- Node.js (for Cloud Functions development)

### Setup

```bash
flutter pub get
```

Create a `.env` file in the project root with the API keys required by the app (Generative AI
key, etc.) — see `lib/main.dart` for what's loaded via `flutter_dotenv`.

### Run the app

```bash
flutter run
```

### Run tests

```bash
flutter test
```

Widget and service tests live alongside their source in `lib/services/` (e.g.
`notification_service_test.dart`) in addition to `test/`.

## Cloud Functions

```bash
cd functions
npm run build   # compile TypeScript
npm run lint    # eslint
npm test        # jest
npm run serve   # functions emulator
npm run deploy  # deploy to Firebase
```

## Firestore rules tests

```bash
firebase emulators:start --only firestore   # in one terminal
npx jest test/firestore.rules.test.js       # in another
```

## Firebase emulators

```bash
firebase emulators:start
```

Boots the full local suite (Auth, Functions, Firestore, Realtime Database, Hosting, Pub/Sub,
Storage, Eventarc, Data Connect, Tasks) as defined in `firebase.json`.

## License

Proprietary — © CogCore LLC. All rights reserved.
