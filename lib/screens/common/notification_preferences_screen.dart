import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _smartNudgesEnabled = true;
  bool _morningRoutineEnabled = true;
  bool _windDownEnabled = false;

  TimeOfDay _morningTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _windDownTime = const TimeOfDay(hour: 21, minute: 0);

  Future<void> _selectTime(BuildContext context, bool isMorning) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isMorning ? _morningTime : _windDownTime,
    );
    if (picked != null) {
      setState(() {
        if (isMorning) {
          _morningTime = picked;
          _morningRoutineEnabled = true;
        } else {
          _windDownTime = picked;
          _windDownEnabled = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Smart Reminders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1F36),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Daily Quotes & Nudges'),
            subtitle: const Text(
              'Receive motivating quotes based on your focus areas.',
            ),
            value: _smartNudgesEnabled,
            activeThumbColor: const Color(0xFF1A1F36),
            onChanged: (bool value) {
              HapticFeedback.lightImpact();
              setState(() => _smartNudgesEnabled = value);
            },
          ),
          const Divider(height: 32),
          const Text(
            'Routine Schedules',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1F36),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Morning Routine'),
            subtitle: Text('Scheduled for ${_morningTime.format(context)}'),
            trailing: Switch(
              value: _morningRoutineEnabled,
              activeThumbColor: const Color(0xFF1A1F36),
              onChanged: (bool value) {
                HapticFeedback.lightImpact();
                setState(() => _morningRoutineEnabled = value);
              },
            ),
            onTap: () => _selectTime(context, true),
          ),
          ListTile(
            title: const Text('Wind Down'),
            subtitle: Text('Scheduled for ${_windDownTime.format(context)}'),
            trailing: Switch(
              value: _windDownEnabled,
              activeThumbColor: const Color(0xFF1A1F36),
              onChanged: (bool value) {
                HapticFeedback.lightImpact();
                setState(() => _windDownEnabled = value);
              },
            ),
            onTap: () => _selectTime(context, false),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Custom reminder times help you build consistency by anchoring habits to specific parts of your day.',
                    style: TextStyle(color: Colors.blue[800], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
