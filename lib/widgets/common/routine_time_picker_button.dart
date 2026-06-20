import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/routine_provider.dart';
import 'premium_glass_card.dart';

class RoutineTimePickerButton extends StatelessWidget {
  final String sessionType;
  final String initialTime;
  final RoutineProvider routineProvider;

  const RoutineTimePickerButton({
    super.key,
    required this.sessionType,
    required this.initialTime,
    required this.routineProvider,
  });

  TimeOfDay _parseTimeSafely(String timeStr) {
    try {
      if (timeStr.isEmpty) return const TimeOfDay(hour: 8, minute: 0);

      // Detect AM/PM and strip out all non-numeric characters (except colon)
      final isPM = timeStr.toUpperCase().contains('PM');
      final isAM = timeStr.toUpperCase().contains('AM');
      final cleanTime = timeStr.replaceAll(RegExp(r'[A-Za-z\s]'), '');

      final parts = cleanTime.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0].trim());
        final int minute = int.parse(parts[1].trim());

        // Adjust for 24-hour TimeOfDay internally
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;

        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {
      // Silently fall through if any parsing fails
    }
    // Default fallback to prevent crash
    return const TimeOfDay(hour: 8, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final TimeOfDay? newTime = await showTimePicker(
          context: context,
          initialTime: _parseTimeSafely(initialTime),
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF00E5FF),
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
              child: PremiumGlassCard(padding: EdgeInsets.zero, child: child!),
            );
          },
        );

        if (newTime != null && context.mounted) {
          // Format strictly to 12-hour AM/PM string before saving
          int hour12 = newTime.hour % 12;
          if (hour12 == 0) hour12 = 12;
          final String amPm = newTime.hour >= 12 ? 'PM' : 'AM';

          final formattedTime =
              '${hour12.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')} $amPm';

          routineProvider.updateRoutineTime(sessionType, 0, formattedTime);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alarm_rounded, color: Color(0xFF00E5FF), size: 14),
            const SizedBox(width: 6),
            Text(
              routineProvider.getRoutineTimes(sessionType).isNotEmpty
                  ? routineProvider.getRoutineTimes(sessionType).first
                  : initialTime,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
