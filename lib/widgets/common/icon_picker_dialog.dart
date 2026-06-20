import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/icon_utils.dart';
import 'premium_glass_card.dart';

class IconPickerDialog extends StatelessWidget {
  final int currentIconCode;

  const IconPickerDialog({super.key, required this.currentIconCode});

  static Future<int?> show(BuildContext context, int currentIconCode) {
    return showDialog<int>(
      context: context,
      builder: (context) => IconPickerDialog(currentIconCode: currentIconCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: PremiumGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Icon',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: supportedIcons.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  final icon = supportedIcons[index];
                  final isSelected = icon.codePoint == currentIconCode;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, icon.codePoint);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00E5FF)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? const Color(0xFF00E5FF)
                            : Colors.white54,
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
