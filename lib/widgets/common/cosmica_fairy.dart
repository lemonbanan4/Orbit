import 'package:flutter/material.dart';

/// Path for Cosmica's animated mascot -- an **animated WebP** of the fairy with
/// her wings fluttering. Flutter's [Image.asset] plays animated WebP natively,
/// so there's no extra runtime and no native dependency (unlike Rive). Keep it
/// small: a few hundred KB, transparent background.
///
/// `assets/images/` is already declared in pubspec, so simply dropping a real
/// `cosmica.webp` in there bundles it -- every [CosmicaFairy] then animates
/// automatically. Until it exists, we transparently fall back to the static
/// `fairy_avatar.png` via [Image.asset]'s errorBuilder, so the UI is never
/// blank or broken.
const String kCosmicaAnimatedAsset = 'assets/images/cosmica.webp';

/// Orbit's mascot, Cosmica. Shows the animated WebP at [animatedAsset] when it's
/// bundled, else the static [fallbackImage]. Drop-in replacement for
/// `Image.asset('assets/images/fairy_avatar.png')` anywhere Cosmica appears.
class CosmicaFairy extends StatelessWidget {
  /// Rendered box size (square). The art scales via [fit].
  final double size;

  final BoxFit fit;

  /// Shown whenever the animated asset isn't present.
  final String fallbackImage;

  final String animatedAsset;

  const CosmicaFairy({
    super.key,
    this.size = 120,
    this.fit = BoxFit.contain,
    this.fallbackImage = 'assets/images/fairy_avatar.png',
    this.animatedAsset = kCosmicaAnimatedAsset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        animatedAsset,
        fit: fit,
        gaplessPlayback: true,
        // No animated WebP bundled yet -> static fairy. Silent by design.
        errorBuilder: (_, _, _) => Image.asset(fallbackImage, fit: fit),
      ),
    );
  }
}
