/// One day of attendance for one employee.
///
/// [date] is a `yyyy-MM-dd` string so records group cleanly by calendar day.
/// [checkIn] and [checkOut] are full ISO timestamps; either may be null when
/// the employee has not checked in or out yet.
class AttendanceRecord {
  const AttendanceRecord({
    required this.employeeId,
    required this.date,
    this.checkIn,
    this.checkOut,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      employeeId: json['employeeId'] as String,
      date: json['date'] as String,
      checkIn: json['checkIn'] == null
          ? null
          : DateTime.parse(json['checkIn'] as String),
      checkOut: json['checkOut'] == null
          ? null
          : DateTime.parse(json['checkOut'] as String),
    );
  }

  final String employeeId;
  final String date;
  final DateTime? checkIn;
  final DateTime? checkOut;

  bool get isPresent => checkIn != null;

  bool get isCheckedOut => checkOut != null;

  /// Worked time for the day, or null when the day is incomplete.
  Duration? get workedDuration {
    final inTime = checkIn;
    final outTime = checkOut;
    if (inTime == null || outTime == null) return null;
    final diff = outTime.difference(inTime);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Hours worked as a decimal, 0 when the day is incomplete.
  double get workedHours => (workedDuration?.inMinutes ?? 0) / 60.0;

  String get status {
    if (checkOut != null) return 'Checked out';
    if (checkIn != null) return 'Present';
    return 'Absent';
  }

  AttendanceRecord copyWith({DateTime? checkIn, DateTime? checkOut}) {
    return AttendanceRecord(
      employeeId: employeeId,
      date: date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'date': date,
        'checkIn': checkIn?.toIso8601String(),
        'checkOut': checkOut?.toIso8601String(),
      };
}
