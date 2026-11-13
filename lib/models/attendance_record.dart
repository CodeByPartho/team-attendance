/// One day of attendance for one employee.
///
/// [date] is a `yyyy-MM-dd` string so records group cleanly by calendar day.
/// [checkIn] and [checkOut] are full ISO timestamps; either may be null when
/// the employee has not checked in or out yet.
///
/// v1.1 adds breaks, edit history and auto check out. [edited] is true when
/// a time on the record was corrected by hand, with the reason in
/// [editReason] (for example 'forgot', 'late' or 'half day'). [autoCheckout]
/// is true when the app closed the day automatically at office end time.
class AttendanceRecord {
  const AttendanceRecord({
    required this.employeeId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.breakStart,
    this.breakEnd,
    this.editReason,
    this.edited = false,
    this.autoCheckout = false,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        value == null ? null : DateTime.parse(value as String);
    return AttendanceRecord(
      employeeId: json['employeeId'] as String,
      date: json['date'] as String,
      checkIn: parseDate(json['checkIn']),
      checkOut: parseDate(json['checkOut']),
      breakStart: parseDate(json['breakStart']),
      breakEnd: parseDate(json['breakEnd']),
      editReason: json['editReason'] as String?,
      edited: json['edited'] as bool? ?? false,
      autoCheckout: json['autoCheckout'] as bool? ?? false,
    );
  }

  final String employeeId;
  final String date;
  final DateTime? checkIn;
  final DateTime? checkOut;

  /// Break start and end, both null when no break was taken.
  final DateTime? breakStart;
  final DateTime? breakEnd;

  /// Why the record was edited, for example 'forgot', 'late', 'half day'.
  final String? editReason;

  /// True when a time on this record was corrected by hand.
  final bool edited;

  /// True when check out was filled in automatically at office end.
  final bool autoCheckout;

  bool get isPresent => checkIn != null;

  bool get isCheckedOut => checkOut != null;

  /// Break length in whole minutes, 0 when the break is incomplete.
  int get breakMinutes {
    final start = breakStart;
    final end = breakEnd;
    if (start == null || end == null) return 0;
    final diff = end.difference(start).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  /// Worked time for the day minus break time, or null when incomplete.
  Duration? get workedDuration {
    final inTime = checkIn;
    final outTime = checkOut;
    if (inTime == null || outTime == null) return null;
    final diff = outTime.difference(inTime);
    final net = diff - Duration(minutes: breakMinutes);
    return net.isNegative ? Duration.zero : net;
  }

  /// Hours worked as a decimal, 0 when the day is incomplete.
  double get workedHours => (workedDuration?.inMinutes ?? 0) / 60.0;

  String get status {
    if (checkOut != null) return 'Checked out';
    if (checkIn != null) return 'Present';
    return 'Absent';
  }

  AttendanceRecord copyWith({
    DateTime? checkIn,
    DateTime? checkOut,
    DateTime? breakStart,
    DateTime? breakEnd,
    String? editReason,
    bool? edited,
    bool? autoCheckout,
    bool clearBreak = false,
    bool clearCheckOut = false,
  }) {
    return AttendanceRecord(
      employeeId: employeeId,
      date: date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: clearCheckOut ? null : (checkOut ?? this.checkOut),
      breakStart: clearBreak ? null : (breakStart ?? this.breakStart),
      breakEnd: clearBreak ? null : (breakEnd ?? this.breakEnd),
      editReason: editReason ?? this.editReason,
      edited: edited ?? this.edited,
      autoCheckout: autoCheckout ?? this.autoCheckout,
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'date': date,
        'checkIn': checkIn?.toIso8601String(),
        'checkOut': checkOut?.toIso8601String(),
        'breakStart': breakStart?.toIso8601String(),
        'breakEnd': breakEnd?.toIso8601String(),
        'editReason': editReason,
        'edited': edited,
        'autoCheckout': autoCheckout,
      };
}
