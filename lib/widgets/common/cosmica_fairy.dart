import 'package:flutter/material.dart';
// Rive also exports an `Image` type; hide it so Flutter's `Image.asset` wins.
import 'package:rive/rive.dart' hide Image;

/// Asset path for Cosmica's animated Rive rig. Drop a real `.riv` here (authored
/// in the Rive editor -- wings flutter etc.) and the whole app animates with no
/// code change. Until then, [CosmicaFairy] transparently shows the static image.
const String kCosmicaRiveAsset = 'assets/rive/cosmica.riv';

/// Master switch for the animated rig. OFF until the runtime is upgraded to
/// rive 0.14 (rive_native) -- the pinned 0.13 runtime can't render .riv files
/// exported from the current Rive editor (it throws on newer fill types and
/// renders blank). While false, CosmicaFairy always shows the static fairy, so
/// the app stays clean. Flip to true once we're on the 0.14 runtime.
const bool kCosmicaRiveEnabled = false;

/// Orbit's mascot, Cosmica. Plays the Rive animation at [riveAsset] when a valid
/// `.riv` is bundled, and gracefully falls back to the static [fallbackImage]
/// otherwise -- so the UI is never blank or broken while the animation file is
/// still a placeholder.
///
/// This is a drop-in replacement for `Image.asset('assets/images/fairy_avatar
/// .png')`: swap it in anywhere Cosmica appears (dashboard insights, coaching,
/// the Constellation Builder) and every instance lights up the moment a real
/// `.riv` lands at [kCosmicaRiveAsset].
///
/// Rive authoring notes (for the designer):
/// * Export a single artboard with the wing-flutter as its default animation,
///   or wire a state machine and pass its name via [stateMachine] (e.g. 'Idle').
/// * Interactive later: a state machine can expose inputs (idle vs. "talking"
///   while Cosmica delivers an AI insight) that we drive from Dart.
class CosmicaFairy extends StatefulWidget {
  /// Rendered box size (square). The rig scales via [fit].
  final double size;

  final BoxFit fit;

  /// Shown while the `.riv` loads, and permanently if it's missing/invalid.
  final String fallbackImage;

  /// Optional Rive state-machine name to drive. When null, the file's default
  /// animation plays -- the most "just works" option for a simple loop.
  final String? stateMachine;

  final String riveAsset;

  const CosmicaFairy({
    super.key,
    this.size = 120,
    this.fit = BoxFit.contain,
    this.fallbackImage = 'assets/images/fairy_avatar.png',
    this.stateMachine,
    this.riveAsset = kCosmicaRiveAsset,
  });

  @override
  State<CosmicaFairy> createState() => _CosmicaFairyState();
}

class _CosmicaFairyState extends State<CosmicaFairy> {
  late final Future<RiveFile?> _fileFuture = _load();

  Future<RiveFile?> _load() async {
    if (!kCosmicaRiveEnabled) return null; // gated off: use static fallback
    try {
      return await RiveFile.asset(widget.riveAsset);
    } catch (_) {
      // Missing / placeholder / invalid .riv -> fall back to the static image.
      // Silent by design: a placeholder asset is the expected pre-launch state.
      return null;
    }
  }

  Widget _fallback() => Image.asset(widget.fallbackImage, fit: widget.fit);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<RiveFile?>(
        future: _fileFuture,
        builder: (context, snap) {
          final file = snap.data;
          if (snap.connectionState == ConnectionState.done && file != null) {
            return RiveAnimation.direct(
              file,
              fit: widget.fit,
              stateMachines:
                  widget.stateMachine != null ? [widget.stateMachine!] : const [],
              placeHolder: _fallback(),
            );
          }
          // Loading or no valid rig: static fairy, never a blank gap.
          return _fallback();
        },
      ),
    );
  }
}
