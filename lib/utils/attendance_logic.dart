import '../models/app_settings.dart';
import '../models/attendance_record.dart';
import '../models/employee.dart';

/// Pure attendance math, kept free of Flutter and storage so every rule is
/// unit testable on its own. The provider calls into these helpers.

/// Split one day of hours into regular and overtime under the per-day rule.
({double regular, double overtime}) splitDayHours(
  double hours,
  double standardHours,
) {
  if (hours <= standardHours) return (regular: hours, overtime: 0);
  return (regular: standardHours, overtime: hours - standardHours);
}

/// Split a list of daily hours for one calendar week into regular and
/// overtime under the per-week rule: overtime is everything over 48 hours.
({double regular, double overtime}) splitWeekHours(
  List<double> dayHours, {
  double weeklyThreshold = 48,
}) {
  final total = dayHours.fold<double>(0, (sum, h) => sum + h);
  if (total <= weeklyThreshold) return (regular: total, overtime: 0);
  return (regular: weeklyThreshold, overtime: total - weeklyThreshold);
}

/// Monday of the week containing [day], used to group records by week.
DateTime weekStart(DateTime day) =>
    DateTime(day.year, day.month, day.day).subtract(
      Duration(days: day.weekday - 1),
    );

/// Regular and overtime hours across a set of records under [settings].
/// The 'day' rule splits each day; the 'week' rule groups by calendar week
/// and splits each week at 48 hours.
({double regular, double overtime}) splitRegularOvertime(
  List<AttendanceRecord> records,
  AppSettings settings,
) {
  var regular = 0.0;
  var overtime = 0.0;
  if (settings.overtimeRule == 'week') {
    final byWeek = <DateTime, List<double>>{};
    for (final r in records) {
      if (r.checkIn == null) continue;
      final key = weekStart(r.checkIn!);
      (byWeek[key] ??= []).add(r.workedHours);
    }
    for (final hours in byWeek.values) {
      final split = splitWeekHours(hours);
      regular += split.regular;
      overtime += split.overtime;
    }
  } else {
    for (final r in records) {
      final split = splitDayHours(r.workedHours, settings.standardHoursPerDay);
      regular += split.regular;
      overtime += split.overtime;
    }
  }
  return (regular: regular, overtime: overtime);
}

/// Monthly pay estimate. Unpaid leave is 0 because leave is not tracked yet.
/// The result is an estimate, not a payslip.
double payrollEstimate({
  required double regularHours,
  required double overtimeHours,
  required double hourlyRate,
  required double overtimeMultiplier,
}) {
  return regularHours * hourlyRate +
      overtimeHours * hourlyRate * overtimeMultiplier;
}

/// Number of working days in a month, counting only days up to [upToDay]
/// (defaults to the whole month). Working days come from settings.
int countWorkingDays(
  int year,
  int month,
  Set<int> workingDays, {
  int? upToDay,
}) {
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final last = upToDay == null
      ? daysInMonth
      : (upToDay < daysInMonth ? upToDay : daysInMonth);
  var count = 0;
  for (var day = 1; day <= last; day++) {
    if (workingDays.contains(DateTime(year, month, day).weekday)) count++;
  }
  return count;
}

/// One row of the team monthly report.
class TeamReportRow {
  const TeamReportRow({
    required this.employee,
    required this.daysPresent,
    required this.daysAbsent,
    required this.leaveDays,
    required this.lateDays,
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.attendancePercent,
    required this.payEstimate,
  });

  final Employee employee;
  final int daysPresent;
  final int daysAbsent;

  /// Leave days. Always 0: leave management is not implemented yet.
  final int leaveDays;
  final int lateDays;
  final double totalHours;
  final double regularHours;
  final double overtimeHours;

  /// Present days as a percentage of working days elapsed.
  final double attendancePercent;
  final double payEstimate;
}

/// Build the team monthly report from plain lists. [now] is injected so
/// tests can pin the current date.
List<TeamReportRow> aggregateTeamReport({
  required List<Employee> employees,
  required List<AttendanceRecord> records,
  required int year,
  required int month,
  required AppSettings settings,
  required DateTime now,
}) {
  final prefix =
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
  final isCurrentMonth = year == now.year && month == now.month;
  final workingDaysElapsed = countWorkingDays(
    year,
    month,
    settings.workingDays,
    upToDay: isCurrentMonth ? now.day : null,
  );
  final rows = <TeamReportRow>[];
  for (final employee in employees) {
    final monthRecords = records
        .where(
          (r) => r.employeeId == employee.id && r.date.startsWith(prefix),
        )
        .toList();
    var present = 0;
    var late = 0;
    for (final r in monthRecords) {
      if (r.checkIn == null) continue;
      present++;
      if (settings.isLate(r.checkIn!)) late++;
    }
    final split = splitRegularOvertime(monthRecords, settings);
    final total = split.regular + split.overtime;
    final absent = workingDaysElapsed - present;
    rows.add(
      TeamReportRow(
        employee: employee,
        daysPresent: present,
        daysAbsent: absent < 0 ? 0 : absent,
        leaveDays: 0,
        lateDays: late,
        totalHours: total,
        regularHours: split.regular,
        overtimeHours: split.overtime,
        attendancePercent: workingDaysElapsed == 0
            ? 0
            : present / workingDaysElapsed * 100,
        payEstimate: payrollEstimate(
          regularHours: split.regular,
          overtimeHours: split.overtime,
          hourlyRate: employee.hourlyRate,
          overtimeMultiplier: settings.overtimeMultiplier,
        ),
      ),
    );
  }
  rows.sort((a, b) => a.employee.name.compareTo(b.employee.name));
  return rows;
}

/// Validate a decoded backup JSON object. Returns an error message when the
/// backup is not usable, or null when it is valid.
String? validateBackupJson(Object? decoded) {
  if (decoded is! Map<String, dynamic>) {
    return 'Backup is not a JSON object.';
  }
  if (decoded['app'] != 'team-attendance') {
    return 'Backup is not a Team Attendance backup.';
  }
  final employees = decoded['employees'];
  final records = decoded['records'];
  if (employees is! List || records is! List) {
    return 'Backup is missing the employees or records list.';
  }
  for (final entry in employees) {
    if (entry is! Map<String, dynamic>) {
      return 'Backup has an employee entry that is not an object.';
    }
    if (entry['id'] is! String ||
        entry['name'] is! String ||
        entry['role'] is! String) {
      return 'Backup has an employee missing id, name or role.';
    }
  }
  for (final entry in records) {
    if (entry is! Map<String, dynamic>) {
      return 'Backup has an attendance entry that is not an object.';
    }
    if (entry['employeeId'] is! String || entry['date'] is! String) {
      return 'Backup has an attendance record missing employeeId or date.';
    }
    final date = entry['date'] as String;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      return 'Backup has an attendance record with a bad date: $date.';
    }
  }
  return null;
}

/// Rows for the Summary sheet of the .xlsx export and the PDF table.
/// First row is the header.
List<List<Object?>> buildSummarySheetRows(
  List<TeamReportRow> rows,
  String currency,
) {
  final out = <List<Object?>>[
    [
      'Employee',
      'Role',
      'Present',
      'Absent',
      'Leave',
      'Late',
      'Total hours',
      'Regular hours',
      'Overtime hours',
      'Attendance %',
      'Pay estimate ($currency)',
    ],
  ];
  for (final row in rows) {
    out.add([
      row.employee.name,
      row.employee.role,
      row.daysPresent,
      row.daysAbsent,
      row.leaveDays,
      row.lateDays,
      double.parse(row.totalHours.toStringAsFixed(2)),
      double.parse(row.regularHours.toStringAsFixed(2)),
      double.parse(row.overtimeHours.toStringAsFixed(2)),
      double.parse(row.attendancePercent.toStringAsFixed(1)),
      double.parse(row.payEstimate.toStringAsFixed(2)),
    ]);
  }
  return out;
}

/// Rows for the Detail sheet of the .xlsx export. First row is the header.
List<List<Object?>> buildDetailSheetRows(
  List<AttendanceRecord> records,
  Map<String, Employee> employeesById,
) {
  final out = <List<Object?>>[
    [
      'Employee',
      'Role',
      'Date',
      'Check in',
      'Check out',
      'Break minutes',
      'Hours worked',
      'Regular hours',
      'Overtime hours',
      'Status',
      'Edited',
      'Edit reason',
    ],
  ];
  String time(DateTime? value) => value == null
      ? ''
      : '${value.hour.toString().padLeft(2, '0')}:'
          '${value.minute.toString().padLeft(2, '0')}';
  final sorted = [...records];
  sorted.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    final aName = employeesById[a.employeeId]?.name ?? a.employeeId;
    final bName = employeesById[b.employeeId]?.name ?? b.employeeId;
    return aName.compareTo(bName);
  });
  for (final r in sorted) {
    final employee = employeesById[r.employeeId];
    out.add([
      employee?.name ?? r.employeeId,
      employee?.role ?? '',
      r.date,
      time(r.checkIn),
      time(r.checkOut),
      r.breakMinutes,
      double.parse(r.workedHours.toStringAsFixed(2)),
      '',
      '',
      r.status,
      r.edited ? 'Yes' : 'No',
      r.editReason ?? '',
    ]);
  }
  return out;
}
