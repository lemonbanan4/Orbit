import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../theme/orbit_tokens.dart';

class PackageCard extends StatelessWidget {
  final Package package;
  final bool isSelected;
  final Function(Package) onSelect;

  const PackageCard({
    super.key,
    required this.package,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAnnual = package.packageType == PackageType.annual;
    final String title = isAnnual ? "Annual" : "Monthly";
    final String priceString = package.storeProduct.priceString;
    final String period = isAnnual ? "/yr" : "/mo";

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () => onSelect(package),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? OrbitTokens.teal.withValues(alpha: 0.10)
                    : OrbitTokens.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? OrbitTokens.teal : OrbitTokens.hairline,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color:
                            isSelected ? OrbitTokens.teal : OrbitTokens.inkFaint,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: OrbitTokens.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        "$priceString$period",
                        style: TextStyle(
                          color:
                              isSelected ? OrbitTokens.teal : OrbitTokens.inkDim,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (isAnnual) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      // Used to also show a crossed-out "was" price hardcoded
                      // at 2x the real price with no factual basis -- a fake
                      // discount claim, which is exactly the kind of thing
                      // Google's Unacceptable Business Practices policy
                      // (misleading pricing) flags accounts for. Real price
                      // + real trial terms only, nothing invented.
                      child: Text(
                        "7 days free, then $priceString$period",
                        style: TextStyle(
                          color: OrbitTokens.inkDim,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isAnnual)
              Positioned(
                top: -2,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: OrbitTokens.teal,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    "MOST POPULAR",
                    style: TextStyle(
                      color: OrbitTokens.ground,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
