import 'package:flutter/material.dart';
import '../../theme/orbit_tokens.dart';

/// A single icon + title + subtitle row describing one Pro benefit.
/// Shared between the full paywall screen and the lightweight upsell
/// dialog so both surfaces advertise the same, grounded feature list.
class PaywallFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const PaywallFeatureRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: OrbitTokens.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: OrbitTokens.hairline),
          ),
          child: Icon(icon, color: OrbitTokens.teal, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: OrbitTokens.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  color: OrbitTokens.inkDim,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
