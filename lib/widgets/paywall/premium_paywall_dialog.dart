import 'package:flutter/material.dart';
import '../common/premium_glass_card.dart';

class PremiumPaywallDialog extends StatefulWidget {
  final String title;
  final String description;
  final VoidCallback onUpgradePressed;
  final VoidCallback onCancelPressed;

  const PremiumPaywallDialog({
    super.key,
    required this.title,
    required this.description,
    required this.onUpgradePressed,
    required this.onCancelPressed,
  });

  @override
  State<PremiumPaywallDialog> createState() => _PremiumPaywallDialogState();
}

class _PremiumPaywallDialogState extends State<PremiumPaywallDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Subtle breathing animation loop for the primary CTA button
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1F1235), // Deep space violet
                Color(0xFF0F2027), // Deep space blue/black
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          // Swap this with your original PremiumGlassCard implementation wrapper
          child: PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      height: 1.4,
                      decoration: TextDecoration.none,
                    ),
                  ),

                  // ==========================================
                  // TODO: FUTURE FEATURES LIST GOES HERE
                  // You can drop a ListView.builder or custom Rows here later
                  // ==========================================
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: widget.onCancelPressed,
                        child: const Text(
                          "Not Now",
                          style: TextStyle(color: Colors.white60, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange.shade800,
                            elevation: 4,
                            shadowColor: Colors.orange.withValues(alpha: 0.2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: widget.onUpgradePressed,
                          child: const Text(
                            "Upgrade to Pro",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
