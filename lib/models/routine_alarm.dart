class RoutineAlarm {
  String time;
  List<bool> activeDays;

  RoutineAlarm({required this.time, required this.activeDays});

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'activeDays': activeDays,
    };
  }

  factory RoutineAlarm.fromMap(Map<String, dynamic> map) {
    return RoutineAlarm(
      time: map['time'] ?? '12:00',
      activeDays: List<bool>.from(
          map['activeDays'] ?? [true, true, true, true, true, false, false]),
    );
  }
}
