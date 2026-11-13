/// App wide settings, persisted as JSON in shared_preferences next to
/// employees and records. All defaults keep the v1.0 behaviour: office
/// start 9:00 AM with 15 minutes grace, so late still means after 9:15 AM
/// until the user changes it.
class AppSettings {
  const AppSettings({
    this.workingDays = const {1, 2, 3, 4, 5},
    this.officeStartHour = 9,
    this.officeStartMinute = 0,
    this.lateGraceMinutes = 15,
    this.standardHoursPerDay = 8.0,
    this.overtimeRule = 'day',
    this.overtimeMultiplier = 1.5,
    this.currency = 'BDT',
    this.reminderTimes = const ['09:00', '17:30'],
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final days = json['workingDays'];
    final reminders = json['reminderTimes'];
    return AppSettings(
      workingDays: days is List
          ? days.map((d) => (d as num).toInt()).toSet()
          : const {1, 2, 3, 4, 5},
      officeStartHour: (json['officeStartHour'] as num?)?.toInt() ?? 9,
      officeStartMinute: (json['officeStartMinute'] as num?)?.toInt() ?? 0,
      lateGraceMinutes: (json['lateGraceMinutes'] as num?)?.toInt() ?? 15,
      standardHoursPerDay:
          (json['standardHoursPerDay'] as num?)?.toDouble() ?? 8.0,
      overtimeRule: json['overtimeRule'] as String? ?? 'day',
      overtimeMultiplier:
          (json['overtimeMultiplier'] as num?)?.toDouble() ?? 1.5,
      currency: json['currency'] as String? ?? 'BDT',
      reminderTimes: reminders is List
          ? reminders.map((r) => r.toString()).toList()
          : const ['09:00', '17:30'],
    );
  }

  /// Weekdays the team works, 1 is Monday and 7 is Sunday.
  final Set<int> workingDays;

  /// Office start time, 24 hour clock.
  final int officeStartHour;
  final int officeStartMinute;

  /// Minutes after office start before a check in counts as late.
  final int lateGraceMinutes;

  /// Standard paid hours in one working day.
  final double standardHoursPerDay;

  /// 'day' means overtime is hours over standardHoursPerDay in one day.
  /// 'week' means overtime is hours over 48 in one calendar week.
  final String overtimeRule;

  /// Pay multiplier applied to overtime hours.
  final double overtimeMultiplier;

  /// Currency code used for pay estimates, for example BDT.
  final String currency;

  /// Reminder times as 'HH:mm' strings. Reminders are stored only; the
  /// app does not schedule notifications yet.
  final List<String> reminderTimes;

  /// The latest check in time that is still on time, on the given day.
  DateTime lateLimitFor(DateTime day) {
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      officeStartHour,
      officeStartMinute,
    );
    return start.add(Duration(minutes: lateGraceMinutes));
  }

  /// True when [checkIn] is after the late limit for its day.
  bool isLate(DateTime checkIn) => checkIn.isAfter(lateLimitFor(checkIn));

  /// Office end time for a day: start plus standard hours.
  DateTime officeEndFor(DateTime day) {
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      officeStartHour,
      officeStartMinute,
    );
    final minutes = (standardHoursPerDay * 60).round();
    return start.add(Duration(minutes: minutes));
  }

  String get lateLabel {
    final limit = lateLimitFor(DateTime(2026, 1, 5));
    final hour = limit.hour;
    final minute = limit.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return 'after $hour12:$minute $suffix';
  }

  Map<String, dynamic> toJson() => {
        'workingDays': workingDays.toList()..sort(),
        'officeStartHour': officeStartHour,
        'officeStartMinute': officeStartMinute,
        'lateGraceMinutes': lateGraceMinutes,
        'standardHoursPerDay': standardHoursPerDay,
        'overtimeRule': overtimeRule,
        'overtimeMultiplier': overtimeMultiplier,
        'currency': currency,
        'reminderTimes': reminderTimes,
      };

  AppSettings copyWith({
    Set<int>? workingDays,
    int? officeStartHour,
    int? officeStartMinute,
    int? lateGraceMinutes,
    double? standardHoursPerDay,
    String? overtimeRule,
    double? overtimeMultiplier,
    String? currency,
    List<String>? reminderTimes,
  }) {
    return AppSettings(
      workingDays: workingDays ?? this.workingDays,
      officeStartHour: officeStartHour ?? this.officeStartHour,
      officeStartMinute: officeStartMinute ?? this.officeStartMinute,
      lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
      standardHoursPerDay: standardHoursPerDay ?? this.standardHoursPerDay,
      overtimeRule: overtimeRule ?? this.overtimeRule,
      overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
      currency: currency ?? this.currency,
      reminderTimes: reminderTimes ?? this.reminderTimes,
    );
  }
}
