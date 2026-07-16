import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/common/premium_glass_card.dart';
import '../theme/orbit_colors.dart';

class TimePickerUtils {
  static Future<TimeOfDay?> showPremiumTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
  }) {
    final accent =
        Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accent,
              onPrimary: Colors.black,
              surface: Colors.transparent,
              onSurface: Colors.white,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.transparent,
              elevation: 0,
              dialBackgroundColor: Colors.white.withValues(alpha: 0.05),
              hourMinuteColor: Colors.white.withValues(alpha: 0.05),
              dayPeriodColor: Colors.white.withValues(alpha: 0.05),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.transparent,
            ),
          ),
          child: PremiumGlassCard(padding: EdgeInsets.zero, child: child!)
              .animate()
              // .fade(duration: 300.ms, curve: Curves.easeOut)
              .scaleXY(
                begin: 0.8,
                end: 1.0,
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),
        );
      },
    );
  }
}
