import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance_record.dart';
import '../models/employee.dart';

/// Monthly totals for one employee.
class MonthlySummary {
  const MonthlySummary({
    required this.employeeId,
    required this.year,
    required this.month,
    required this.daysPresent,
    required this.totalMinutes,
    required this.lateDays,
    required this.daysInMonthSoFar,
  });

  final String employeeId;
  final int year;
  final int month;
  final int daysPresent;
  final int totalMinutes;
  final int lateDays;
  final int daysInMonthSoFar;

  double get totalHours => totalMinutes / 60.0;

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

  /// Office start time used to count a late check in.
  static const int lateHour = 9;
  static const int lateMinute = 15;

  List<Employee> employees = [];
  List<AttendanceRecord> records = [];
  bool loaded = false;

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
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
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
      Employee(id: 'e1', name: 'Rahim Uddin', role: 'Office Manager'),
      Employee(id: 'e2', name: 'Nusrat Jahan', role: 'Flutter Developer'),
      Employee(id: 'e3', name: 'Tanvir Ahmed', role: 'UI Designer'),
      Employee(id: 'e4', name: 'Farhana Akter', role: 'Accountant'),
      Employee(id: 'e5', name: 'Sakib Hasan', role: 'Sales Executive'),
      Employee(id: 'e6', name: 'Mim Chowdhury', role: 'Support Officer'),
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
  Future<Employee> addEmployee(String name, String role) async {
    final employee = Employee(
      id: 'e${DateTime.now().microsecondsSinceEpoch}'
          '_${Random().nextInt(1 << 32)}',
      name: name.trim(),
      role: role.trim().isEmpty ? 'Staff' : role.trim(),
    );
    employees = [...employees, employee];
    await _save();
    notifyListeners();
    return employee;
  }

  Future<void> removeEmployee(String id) async {
    employees = employees.where((e) => e.id != id).toList();
    records = records.where((r) => r.employeeId != id).toList();
    await _save();
    notifyListeners();
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

  /// Everyone on the team with their record for the given day.
  List<RegisterRow> registerFor(DateTime day) {
    return employees
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

  /// Days present and total hours for one employee in one month.
  MonthlySummary monthlySummary(String employeeId, int year, int month) {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final monthRecords = records.where(
      (r) => r.employeeId == employeeId && r.date.startsWith(prefix),
    );
    var daysPresent = 0;
    var totalMinutes = 0;
    var lateDays = 0;
    for (final r in monthRecords) {
      if (r.checkIn == null) continue;
      daysPresent++;
      totalMinutes += r.workedDuration?.inMinutes ?? 0;
      final lateLimit = DateTime(
        r.checkIn!.year,
        r.checkIn!.month,
        r.checkIn!.day,
        lateHour,
        lateMinute,
      );
      if (r.checkIn!.isAfter(lateLimit)) lateDays++;
    }
    final now = DateTime.now();
    final daysSoFar = (year == now.year && month == now.month)
        ? now.day
        : DateTime(year, month + 1, 0).day;
    return MonthlySummary(
      employeeId: employeeId,
      year: year,
      month: month,
      daysPresent: daysPresent,
      totalMinutes: totalMinutes,
      lateDays: lateDays,
      daysInMonthSoFar: daysSoFar,
    );
  }

  /// Full attendance history as CSV text, newest first.
  String toCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Employee,Role,Date,Check In,Check Out,Hours Worked,Status');
    final sorted = [...records];
    sorted.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return _nameOf(a.employeeId).compareTo(_nameOf(b.employeeId));
    });
    final timeFormat = DateFormat('HH:mm');
    for (final r in sorted) {
      final employee = employees.firstWhere(
        (e) => e.id == r.employeeId,
        orElse: () => Employee(id: r.employeeId, name: r.employeeId, role: ''),
      );
      buffer.writeln(
        '${_csvCell(employee.name)},${_csvCell(employee.role)},${r.date},'
        '${r.checkIn == null ? '' : timeFormat.format(r.checkIn!)},'
        '${r.checkOut == null ? '' : timeFormat.format(r.checkOut!)},'
        '${r.workedHours.toStringAsFixed(2)},${r.status}',
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

  /// Clears every employee and attendance record and saves the empty
  /// state, so a real team can start with no demo data left behind.
  Future<void> clearAllData() async {
    employees = [];
    records = [];
    await _save();
    notifyListeners();
  }

  /// Clears all data and reseeds the demo team. Used from Settings.
  Future<void> resetDemoData() async {
    _seedDemoData();
    await _save();
    notifyListeners();
  }
}
