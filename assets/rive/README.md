# Cosmica Rive animations

Drop the real mascot animation here as **`cosmica.riv`** (authored in the
Rive editor at https://rive.app). No code change is needed — `CosmicaFairy`
(`lib/widgets/common/cosmica_fairy.dart`) loads `assets/rive/cosmica.riv`
automatically and shows the static `fairy_avatar.png` until it exists.

Authoring guidance:
- One artboard, wings fluttering as the default looping animation, OR
- A state machine named `Idle` (pass its name to `CosmicaFairy(stateMachine: 'Idle')`).
- Keep the transparent background so it composits over Orbit's dark UI.
