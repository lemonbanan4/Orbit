# Orbit v1.2 — "Intelligence & Stickiness"

Theme: lean into Orbit's AI + data strengths and fix the retention cliff.
Grounded in a 2026 competitive scan (adaptive AI, forgiveness > rigid streaks,
re-engagement, viral share loops).

## Scope (5 features)

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 5 | **Alchemy Insights** | ✅ done | AlchemyInsightsCard on Stats — surfaces real habit-synergy data with strength bars + empty state. |
| 6 | **Shareable recap cards** | ✅ done | WeeklyRecapCard (800x800, StellarPlanet + week bars) + "Share my week" button on Stats, via ShareService. |
| 4 | **Smart re-engagement nudges** | ✅ done | Rolling local-notification ladder (day 2/4/7 at 11am, IDs 8001–8003) that slides forward on every "user active" signal (app boot + habit toggle) and only fires after real silence. Copy is streak-adaptive & forgiving. Respects the master notifications toggle. |
| 1 | **Adaptive AI Missions & Suggestions** | ✅ done | Daily-mission targets now scale to habits genuinely due today (always achievable + meaningful vs. fixed 1/3/5); mission ids/reset preserved. Plus a data-grounded "Suggestions" insight line (real synergy pair, else tailored load) so the personalization is visible. |
| 3 | **Forgiveness & recovery** | ✅ done | A broken streak now records the lost length and greets the user with a warm, guilt-free ComebackBanner ("Your 12-day streak paused — every legend has a comeback") on the dashboard, instead of a silent zero. Clears on rebuild or dismiss. Additive only — does NOT change when/whether streaks break. Streak-freeze "insurance" already shipped. |

## Status: v1.2 COMPLETE ✅ — all 5 features built, analyzer clean.
Ships stacked into v1.1.0 (build 16); not live to users until that update is submitted.

## Build order (ROI + risk)
1. #5 Alchemy Insights — self-contained UI over existing data.
2. #6 Shareable recap cards — reuses share_service; growth.
3. #4 Re-engagement nudges — notification logic.
4. #1 Adaptive AI Missions — builds on missions + alchemy + AI.
5. #3 Forgiveness — touches core streak logic; do last, most carefully.

## Assets already in place to build on
- `alchemy_telemetry_service.dart` — real habit co-occurrence (HabitSynergy).
- Daily Missions (`daily_mission.dart`, `daily_missions_card.dart`).
- `share_service` — widget-to-PNG capture.
- `notification_service` — local + FCM.
- AI: `ai_coach_service`, `ai_fairy_service`, `gemini_gateway`.
- Streak freezes (RoutineProvider) — foundation for forgiveness.
