# Orbit v1.2 — "Intelligence & Stickiness"

Theme: lean into Orbit's AI + data strengths and fix the retention cliff.
Grounded in a 2026 competitive scan (adaptive AI, forgiveness > rigid streaks,
re-engagement, viral share loops).

## Scope (5 features)

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 5 | **Alchemy Insights** | 🔨 in progress | Surface the real habit-synergy data (AlchemyTelemetryService) that today only lives in Nebula Forge — as an Insights card on Stats. Lowest risk, uses existing data. |
| 1 | **Adaptive AI Missions & Suggestions** | ⬜ todo | Personalize Daily Missions + habit suggestions from real completion patterns (alchemy synergy + AI coach). The 2026 headline trend. |
| 3 | **Forgiveness & recovery** | ⬜ todo | Reframe missed days as signals, not failures; comeback flow + streak insurance. Retention. Touches streak logic — build carefully. |
| 4 | **Smart re-engagement nudges** | ⬜ todo | Adaptive notifications that pull lapsed users back ("Cosmica misses you — your Voyager streak is waiting"). |
| 6 | **Shareable recap cards** | ⬜ todo | Extend share_service (widget→PNG) into "Week in Review" / rank-up cards → free viral marketing. |

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
