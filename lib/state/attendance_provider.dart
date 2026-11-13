import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/attendance_record.dart';
import '../models/employee.dart';
import '../utils/attendance_logic.dart' as logic;

/// Monthly totals for one employee.
class MonthlySummary {
  const MonthlySummary({
    required this.employeeId,
    required this.year,
    required this.month,
    required this.daysPresent,
    required this.daysAbsent,
    required this.leaveDays,
    required this.attendancePercent,
    required this.totalMinutes,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.lateDays,
    required this.daysInMonthSoFar,
    required this.payEstimate,
  });

  final String employeeId;
  final int year;
  final int month;
  final int daysPresent;

  /// Working days elapsed with no check in.
  final int daysAbsent;

  /// Leave days. Always 0: leave management is not implemented yet.
  final int leaveDays;

  /// Present days as a percentage of working days elapsed.
  final double attendancePercent;
  final int totalMinutes;
  final int regularMinutes;
  final int overtimeMinutes;
  final int lateDays;
  final int daysInMonthSoFar;

  /// Monthly pay estimate, see [logic.payrollEstimate].
  final double payEstimate;

  double get totalHours => totalMinutes / 60.0;
  double get regularHours => regularMinutes / 60.0;
  double get overtimeHours => overtimeMinutes / 60.0;

  double get averageHoursPerDay =>
      daysPresent == 0 ? 0 : totalHours / daysPresent;
}

/// One row of the today register: an employee plus their record for today.
class RegisterRow {
  const RegisterRow({required this.employee, this.record});

  final Employee employee;
  final AttendanceRecord? record;

  bool get isPresent => record?.isPresent ?? false;
  bool get isCheckedOut => record?.isCheckedOut ?? false;
}

class AttendanceProvider extends ChangeNotifier {
  static const String storageKey = 'team_attendance_v1';
  static const String datePattern = 'yyyy-MM-dd';

  /// Kept for compatibility; late is now computed from [settings].
  static const int lateHour = 9;
  static const int lateMinute = 15;

  List<Employee> employees = [];
  List<AttendanceRecord> records = [];
  AppSettings settings = const AppSettings();
  bool loaded = false;

  /// Active employees only, for the today register and reports.
  List<Employee> get activeEmployees =>
      employees.where((e) => !e.archived).toList();

  /// Archived employees, shown separately with their history intact.
  List<Employee> get archivedEmployees =>
      employees.where((e) => e.archived).toList();

  String dateKey(DateTime day) => DateFormat(datePattern).format(day);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      _seedDemoData();
      await _save();
    } else {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      employees = (data['employees'] as List<dynamic>)
          .map((e) => Employee.fromJson(e as Map<String, dynamic>))
          .toList();
      records = (data['records'] as List<dynamic>)
          .map((r) => AttendanceRecord.fromJson(r as Map<String, dynamic>))
          .toList();
      final savedSettings = data['settings'];
      if (savedSettings is Map<String, dynamic>) {
        settings = AppSettings.fromJson(savedSettings);
      }
      await autoCheckoutOpenRecords();
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'app': 'team-attendance',
      'version': 2,
      'settings': settings.toJson(),
      'employees': employees.map((e) => e.toJson()).toList(),
      'records': records.map((r) => r.toJson()).toList(),
    };
    await prefs.setString(storageKey, jsonEncode(data));
  }

  /// Demo seed: 6 employees with attendance for the current work week
  /// (Monday to today), so the app shows real looking data on first run.
  /// All names and times are invented demo data.
  void _seedDemoData() {
    employees = const [
      Employee(
        id: 'e1',
        name: 'Rahim Uddin',
        role: 'Office Manager',
        department: 'Operations',
        hourlyRate: 350,
      ),
      Employee(
        id: 'e2',
        name: 'Nusrat Jahan',
        role: 'Flutter Developer',
        department: 'Engineering',
        hourlyRate: 500,
      ),
      Employee(
        id: 'e3',
        name: 'Tanvir Ahmed',
        role: 'UI Designer',
        department: 'Design',
        hourlyRate: 450,
      ),
      Employee(
        id: 'e4',
        name: 'Farhana Akter',
        role: 'Accountant',
        department: 'Finance',
        hourlyRate: 400,
      ),
      Employee(
        id: 'e5',
        name: 'Sakib Hasan',
        role: 'Sales Executive',
        department: 'Sales',
        hourlyRate: 300,
      ),
      Employee(
        id: 'e6',
        name: 'Mim Chowdhury',
        role: 'Support Officer',
        department: 'Support',
        hourlyRate: 300,
      ),
    ];
    records = [];
    final today = DateTime.now();
    // Walk back to Monday of this week.
    final monday = today.subtract(Duration(days: today.weekday - 1));
    for (var d = 0; d < today.weekday; d++) {
      final day = monday.add(Duration(days: d));
      final key = dateKey(day);
      for (var i = 0; i < employees.length; i++) {
        // One invented absence pattern: Sakib was off on Wednesday,
        // Mim was off on Tuesday. Everyone else was present.
        if ((employees[i].id == 'e5' && day.weekday == 3) ||
            (employees[i].id == 'e6' && day.weekday == 2)) {
          continue;
        }
        final inMinutes = 9 * 60 + (i * 7) % 25;
        final outMinutes = 17 * 60 + 30 + (i * 11) % 30;
        final checkIn = DateTime(
          day.year,
          day.month,
          day.day,
          inMinutes ~/ 60,
          inMinutes % 60,
        );
        final checkOut = DateTime(
          day.year,
          day.month,
          day.day,
          outMinutes ~/ 60,
          outMinutes % 60,
        );
        // Today is still in progress: no check out yet.
        records.add(
          AttendanceRecord(
            employeeId: employees[i].id,
            date: key,
            checkIn: checkIn,
            checkOut: d == today.weekday - 1 ? null : checkOut,
          ),
        );
      }
    }
  }

  /// Adds an employee. Returns the new employee.
  Future<Employee> addEmployee(
    String name,
    String role, {
    String phone = '',
    String email = '',
    String? joinDate,
    String department = '',
    double hourlyRate = 0,
    String employmentType = 'Full-time',
  }) async {
    final employee = Employee(
      id: 'e${DateTime.now().microsecondsSinceEpoch}'
          '_${Random().nextInt(1 << 32)}',
      name: name.trim(),
      role: role.trim().isEmpty ? 'Staff' : role.trim(),
      phone: phone.trim(),
      email: email.trim(),
      joinDate: joinDate,
      department: department.trim(),
      hourlyRate: hourlyRate,
      employmentType: employmentType,
    );
    employees = [...employees, employee];
    await _save();
    notifyListeners();
    return employee;
  }

  /// Updates an employee in place, keeping their id and history.
  Future<bool> updateEmployee(Employee updated) async {
    final index = employees.indexWhere((e) => e.id == updated.id);
    if (index < 0) return false;
    final copy = [...employees];
    copy[index] = updated;
    employees = copy;
    await _save();
    notifyListeners();
    return true;
  }

  /// Archives an employee: they leave the today register but keep every
  /// attendance record. Returns false when the employee is unknown.
  Future<bool> archiveEmployee(String id) async {
    final employee = employeeById(id);
    if (employee == null || employee.archived) return false;
    return updateEmployee(employee.copyWith(archived: true));
  }

  /// Restores an archived employee to the today register.
  Future<bool> unarchiveEmployee(String id) async {
    final employee = employeeById(id);
    if (employee == null || !employee.archived) return false;
    return updateEmployee(employee.copyWith(archived: false));
  }

  /// Kept for compatibility: removing an employee now archives them
  /// instead of deleting their history.
  Future<void> removeEmployee(String id) async {
    await archiveEmployee(id);
  }

  AttendanceRecord? recordFor(String employeeId, DateTime day) {
    final key = dateKey(day);
    for (final r in records) {
      if (r.employeeId == employeeId && r.date == key) return r;
    }
    return null;
  }

  /// Checks an employee in. Returns false when already checked in today.
  Future<bool> checkIn(String employeeId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    if (recordFor(employeeId, now) != null) return false;
    records = [
      ...records,
      AttendanceRecord(
        employeeId: employeeId,
        date: dateKey(now),
        checkIn: now,
      ),
    ];
    await _save();
    notifyListeners();
    return true;
  }

  /// Checks an employee out. Returns false when not checked in yet or
  /// already checked out.
  Future<bool> checkOut(String employeeId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final record = recordFor(employeeId, now);
    if (record == null || record.checkIn == null || record.checkOut != null) {
      return false;
    }
    if (now.isBefore(record.checkIn!)) return false;
    records = records
        .map(
          (r) => r == record ? r.copyWith(checkOut: now) : r,
        )
        .toList();
    await _save();
    notifyListeners();
    return true;
  }

  /// Starts a break for the employee's open record today.
  Future<bool> startBreak(String employeeId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final record = recordFor(employeeId, now);
    if (record == null ||
        record.checkIn == null ||
        record.checkOut != null ||
        record.breakStart != null) {
      return false;
    }
    if (now.isBefore(record.checkIn!)) return false;
    records = records
        .map((r) => r == record ? r.copyWith(breakStart: now) : r)
        .toList();
    await _save();
    notifyListeners();
    return true;
  }

  /// Ends a break for the employee's open record today.
  Future<bool> endBreak(String employeeId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final record = recordFor(employeeId, now);
    if (record == null ||
        record.breakStart == null ||
        record.breakEnd != null) {
      return false;
    }
    if (now.isBefore(record.breakStart!)) return false;
    records = records
        .map((r) => r == record ? r.copyWith(breakEnd: now) : r)
        .toList();
    await _save();
    notifyListeners();
    return true;
  }

  /// Corrects a record: new check in or out, break times, and a reason.
  /// The record is flagged [AttendanceRecord.edited]. Returns false when
  /// the record does not exist or the new times are impossible (check out
  /// before check in, or a break outside the working day).
  Future<bool> editRecord({
    required String employeeId,
    required DateTime day,
    DateTime? checkIn,
    DateTime? checkOut,
    DateTime? breakStart,
    DateTime? breakEnd,
    bool clearBreak = false,
    String? reason,
  }) async {
    final record = recordFor(employeeId, day);
    if (record == null) return false;
    final newIn = checkIn ?? record.checkIn;
    final newOut = checkOut ?? record.checkOut;
    if (newIn != null && newOut != null && newOut.isBefore(newIn)) {
      return false;
    }
    final newBreakStart = clearBreak ? null : (breakStart ?? record.breakStart);
    final newBreakEnd = clearBreak ? null : (breakEnd ?? record.breakEnd);
    if (newBreakStart != null && newBreakEnd != null) {
      if (newBreakEnd.isBefore(newBreakStart)) return false;
      if (newIn != null && newBreakStart.isBefore(newIn)) return false;
      if (newOut != null && newBreakEnd.isAfter(newOut)) return false;
    }
    final updated = record.copyWith(
      checkIn: newIn,
      checkOut: newOut,
      breakStart: newBreakStart,
      breakEnd: newBreakEnd,
      clearBreak: clearBreak,
      editReason: reason ?? record.editReason,
      edited: true,
      autoCheckout: newOut == null ? record.autoCheckout : false,
    );
    records = records.map((r) => r == record ? updated : r).toList();
    await _save();
    notifyListeners();
    return true;
  }

  /// Auto check out: closes every still open record whose day has ended,
  /// at office end time (office start plus standard hours), flagged as
  /// auto. Runs on load and can be called after the day ends. Returns the
  /// number of records closed.
  Future<int> autoCheckoutOpenRecords({DateTime? now}) async {
    final current = now ?? DateTime.now();
    var closed = 0;
    final updated = records.map((r) {
      if (r.checkIn == null || r.checkOut != null) return r;
      final day = DateTime.parse(r.date);
      final autoOut = settings.officeEndFor(day);
      final isPastDay = r.date.compareTo(dateKey(current)) < 0;
      final isTodayPastEnd =
          r.date == dateKey(current) && current.isAfter(autoOut);
      if (!isPastDay && !isTodayPastEnd) return r;
      closed++;
      return r.copyWith(checkOut: autoOut, autoCheckout: true);
    }).toList();
    if (closed > 0) {
      records = updated;
      await _save();
      notifyListeners();
    }
    return closed;
  }

  /// Saves new settings.
  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await _save();
    notifyListeners();
  }

  /// Everyone active on the team with their record for the given day.
  /// Archived employees do not appear here.
  List<RegisterRow> registerFor(DateTime day) {
    return activeEmployees
        .map((e) => RegisterRow(employee: e, record: recordFor(e.id, day)))
        .toList();
  }

  /// All records for one calendar day, sorted by employee name.
  List<AttendanceRecord> historyFor(DateTime day) {
    final key = dateKey(day);
    final dayRecords =
        records.where((r) => r.date == key).toList(growable: false);
    dayRecords.sort((a, b) {
      final aName = _nameOf(a.employeeId);
      final bName = _nameOf(b.employeeId);
      return aName.compareTo(bName);
    });
    return dayRecords;
  }

  String _nameOf(String employeeId) {
    for (final e in employees) {
      if (e.id == employeeId) return e.name;
    }
    return employeeId;
  }

  Employee? employeeById(String id) {
    for (final e in employees) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Days present, absent, hours and pay estimate for one employee in
  /// one month. Late is counted against office start plus grace from
  /// settings, not a hardcoded time.
  MonthlySummary monthlySummary(String employeeId, int year, int month) {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final monthRecords = records.where(
      (r) => r.employeeId == employeeId && r.date.startsWith(prefix),
    );
    var daysPresent = 0;
    var lateDays = 0;
    for (final r in monthRecords) {
      if (r.checkIn == null) continue;
      daysPresent++;
      if (settings.isLate(r.checkIn!)) lateDays++;
    }
    final split = logic.splitRegularOvertime(monthRecords.toList(), settings);
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;
    final workingDaysElapsed = logic.countWorkingDays(
      year,
      month,
      settings.workingDays,
      upToDay: isCurrentMonth ? now.day : null,
    );
    final daysSoFar = isCurrentMonth
        ? now.day
        : DateTime(year, month + 1, 0).day;
    final absent = workingDaysElapsed - daysPresent;
    final employee = employeeById(employeeId);
    return MonthlySummary(
      employeeId: employeeId,
      year: year,
      month: month,
      daysPresent: daysPresent,
      daysAbsent: absent < 0 ? 0 : absent,
      leaveDays: 0,
      attendancePercent: workingDaysElapsed == 0
          ? 0
          : daysPresent / workingDaysElapsed * 100,
      totalMinutes: ((split.regular + split.overtime) * 60).round(),
      regularMinutes: (split.regular * 60).round(),
      overtimeMinutes: (split.overtime * 60).round(),
      lateDays: lateDays,
      daysInMonthSoFar: daysSoFar,
      payEstimate: logic.payrollEstimate(
        regularHours: split.regular,
        overtimeHours: split.overtime,
        hourlyRate: employee?.hourlyRate ?? 0,
        overtimeMultiplier: settings.overtimeMultiplier,
      ),
    );
  }

  /// Team monthly report for the Reports tab.
  List<logic.TeamReportRow> teamMonthlyReport(
    int year,
    int month, {
    DateTime? now,
  }) {
    return logic.aggregateTeamReport(
      employees: activeEmployees,
      records: records,
      year: year,
      month: month,
      settings: settings,
      now: now ?? DateTime.now(),
    );
  }

  /// Full attendance history as CSV text, newest first. Optional filters
  /// narrow it to a date range, one employee, or both.
  String toCsv({DateTime? from, DateTime? to, String? employeeId}) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Employee,Role,Date,Check In,Check Out,Break Minutes,Hours Worked,'
      'Regular Hours,Overtime Hours,Status,Edited',
    );
    var filtered = [...records];
    if (from != null) {
      filtered = filtered
          .where((r) => r.date.compareTo(dateKey(from)) >= 0)
          .toList();
    }
    if (to != null) {
      filtered = filtered
          .where((r) => r.date.compareTo(dateKey(to)) <= 0)
          .toList();
    }
    if (employeeId != null) {
      filtered =
          filtered.where((r) => r.employeeId == employeeId).toList();
    }
    filtered.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return _nameOf(a.employeeId).compareTo(_nameOf(b.employeeId));
    });
    final timeFormat = DateFormat('HH:mm');
    for (final r in filtered) {
      final employee = employees.firstWhere(
        (e) => e.id == r.employeeId,
        orElse: () => Employee(id: r.employeeId, name: r.employeeId, role: ''),
      );
      final split = logic.splitDayHours(
        r.workedHours,
        settings.standardHoursPerDay,
      );
      buffer.writeln(
        '${_csvCell(employee.name)},${_csvCell(employee.role)},${r.date},'
        '${r.checkIn == null ? '' : timeFormat.format(r.checkIn!)},'
        '${r.checkOut == null ? '' : timeFormat.format(r.checkOut!)},'
        '${r.breakMinutes},'
        '${r.workedHours.toStringAsFixed(2)},'
        '${split.regular.toStringAsFixed(2)},'
        '${split.overtime.toStringAsFixed(2)},'
        '${r.status},${r.edited ? 'Yes' : 'No'}',
      );
    }
    return buffer.toString();
  }

  String _csvCell(String value) {
    if (value.contains(',') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Rows for the Summary and Detail sheets of the .xlsx export.
  List<List<Object?>> summarySheetRows(int year, int month) {
    return logic.buildSummarySheetRows(
      teamMonthlyReport(year, month),
      settings.currency,
    );
  }

  List<List<Object?>> detailSheetRows() {
    final byId = {for (final e in employees) e.id: e};
    return logic.buildDetailSheetRows(records, byId);
  }

  /// The whole data set as a backup JSON string, with app marker and
  /// version so imports can be validated.
  String exportBackupJson() {
    final data = {
      'app': 'team-attendance',
      'version': 2,
      'settings': settings.toJson(),
      'employees': employees.map((e) => e.toJson()).toList(),
      'records': records.map((r) => r.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  /// Imports a backup JSON string after validation. Returns an error
  /// message when the backup is invalid, or null on success. The caller
  /// must confirm the overwrite with the user first.
  Future<String?> importBackupJson(String raw) async {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return 'Backup is not valid JSON.';
    }
    final error = logic.validateBackupJson(decoded);
    if (error != null) return error;
    final data = decoded as Map<String, dynamic>;
    try {
      employees = (data['employees'] as List<dynamic>)
          .map((e) => Employee.fromJson(e as Map<String, dynamic>))
          .toList();
      records = (data['records'] as List<dynamic>)
          .map((r) => AttendanceRecord.fromJson(r as Map<String, dynamic>))
          .toList();
      final savedSettings = data['settings'];
      if (savedSettings is Map<String, dynamic>) {
        settings = AppSettings.fromJson(savedSettings);
      }
    } catch (_) {
      return 'Backup could not be read: a record is malformed.';
    }
    await _save();
    notifyListeners();
    return null;
  }

  /// Clears every employee, attendance record and setting and saves the
  /// empty state, so a real team can start with no demo data left behind.
  Future<void> clearAllData() async {
    employees = [];
    records = [];
    settings = const AppSettings();
    await _save();
    notifyListeners();
  }

  /// Clears all data and reseeds the demo team. Used from Settings.
  Future<void> resetDemoData() async {
    settings = const AppSettings();
    _seedDemoData();
    await _save();
    notifyListeners();
  }
}
