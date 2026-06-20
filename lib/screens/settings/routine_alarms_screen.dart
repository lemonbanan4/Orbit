import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/routine_alarm.dart';
import '../../widgets/common/premium_glass_card.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import '../../services/notification_service.dart';

class RoutineAlarmsScreen extends StatefulWidget {
  const RoutineAlarmsScreen({super.key});

  @override
  State<RoutineAlarmsScreen> createState() => _RoutineAlarmsScreenState();
}

class _RoutineAlarmsScreenState extends State<RoutineAlarmsScreen> {
  @override
  void initState() {
    super.initState();
    // Request exact alarm permissions on Android 14+ when they open the screen
    NotificationService.requestExactAlarmsPermission();
  }

  Future<void> _pickTime(
      String routineType, int alarmIndex, RoutineAlarm currentAlarm) async {
    HapticFeedback.lightImpact();
    final currentParts = currentAlarm.time.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(currentParts[0]),
      minute: int.parse(currentParts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        final formattedTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

        context
            .read<RoutineProvider>()
            .updateRoutineTime(routineType, alarmIndex, formattedTime);
      });
      _showSuccess(routineType);
    }
  }

  void _toggleDay(String routineType, int alarmIndex, int dayIndex,
      RoutineAlarm currentAlarm) {
    HapticFeedback.selectionClick();
    context
        .read<RoutineProvider>()
        .toggleAlarmDay(routineType, alarmIndex, dayIndex);
    _showSuccess(routineType);
  }

  void _showSuccess(String routineType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$routineType alarms updated! 🚀'),
        backgroundColor: const Color(0xFF00E5FF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoutineProvider>();
    final routineTypes = ['Morning', 'Work', 'Night'];

    return Scaffold(
      backgroundColor: const Color(0xFF050112),
      appBar: AppBar(
        title: const Text('Routine Alarms'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: routineTypes.map((routineType) {
          final alarms = provider.getRoutineAlarms(routineType);
          if (alarms.isEmpty) return const SizedBox.shrink();
          final alarm = alarms.first;
          const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: PremiumGlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$routineType Routine',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Time:',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 16)),
                      GestureDetector(
                        onTap: () => _pickTime(routineType, 0, alarm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF00E5FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            alarm.time,
                            style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Active Days:',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final isActive = alarm.activeDays[index];
                      return GestureDetector(
                        onTap: () => _toggleDay(routineType, 0, index, alarm),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: isActive
                              ? const Color(0xFF00E5FF)
                              : Colors.white.withValues(alpha: 0.05),
                          child: Text(
                            days[index],
                            style: TextStyle(
                              color: isActive ? Colors.black : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
