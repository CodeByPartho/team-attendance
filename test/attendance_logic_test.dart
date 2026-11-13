import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:team_attendance/models/attendance_record.dart';
import 'package:team_attendance/state/attendance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttendanceRecord', () {
    test('worked hours are the difference between check in and check out',
        () {
      final record = AttendanceRecord(
        employeeId: 'e1',
        date: '2026-11-09',
        checkIn: DateTime(2026, 11, 9, 9, 0),
        checkOut: DateTime(2026, 11, 9, 17, 30),
      );
      expect(record.workedHours, closeTo(8.5, 0.001));
      expect(record.isPresent, isTrue);
      expect(record.status, 'Checked out');
    });

    test('incomplete day has zero worked hours', () {
      final record = AttendanceRecord(
        employeeId: 'e1',
        date: '2026-11-09',
        checkIn: DateTime(2026, 11, 9, 9, 5),
      );
      expect(record.workedHours, 0);
      expect(record.status, 'Present');
    });

    test('round trips through JSON', () {
      final record = AttendanceRecord(
        employeeId: 'e1',
        date: '2026-11-09',
        checkIn: DateTime(2026, 11, 9, 9, 0),
        checkOut: DateTime(2026, 11, 9, 17, 0),
      );
      final restored = AttendanceRecord.fromJson(record.toJson());
      expect(restored.employeeId, 'e1');
      expect(restored.date, '2026-11-09');
      expect(restored.workedHours, closeTo(8.0, 0.001));
    });
  });

  group('AttendanceProvider check in and check out', () {
    late AttendanceProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = AttendanceProvider();
      await provider.load();
      // Clear the demo seed so tests start from a known empty state.
      provider.employees = [];
      provider.records = [];
    });

    test('check in once, second check in is refused', () async {
      final employee = await provider.addEmployee('Test Person', 'Tester');
      final first = await provider.checkIn(
        employee.id,
        at: DateTime(2026, 11, 9, 9, 0),
      );
      final second = await provider.checkIn(
        employee.id,
        at: DateTime(2026, 11, 9, 9, 30),
      );
      expect(first, isTrue);
      expect(second, isFalse);
      expect(provider.records.length, 1);
    });

    test('check out needs a check in first', () async {
      final employee = await provider.addEmployee('Test Person', 'Tester');
      final result = await provider.checkOut(
        employee.id,
        at: DateTime(2026, 11, 9, 17, 0),
      );
      expect(result, isFalse);
    });

    test('check out after check in records worked hours', () async {
      final employee = await provider.addEmployee('Test Person', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 0));
      final done = await provider.checkOut(
        employee.id,
        at: DateTime(2026, 11, 9, 17, 30),
      );
      expect(done, isTrue);
      final record = provider.recordFor(employee.id, DateTime(2026, 11, 9));
      expect(record?.workedHours, closeTo(8.5, 0.001));
      // A second check out is refused.
      final again = await provider.checkOut(
        employee.id,
        at: DateTime(2026, 11, 9, 18, 0),
      );
      expect(again, isFalse);
    });

    test('check out before check in is refused', () async {
      final employee = await provider.addEmployee('Test Person', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 0));
      final result = await provider.checkOut(
        employee.id,
        at: DateTime(2026, 11, 9, 8, 0),
      );
      expect(result, isFalse);
    });

    test('monthly summary counts days present and total hours', () async {
      final employee = await provider.addEmployee('Test Person', 'Tester');
      for (var day = 2; day <= 4; day++) {
        await provider.checkIn(
          employee.id,
          at: DateTime(2026, 11, day, 9, 0),
        );
        await provider.checkOut(
          employee.id,
          at: DateTime(2026, 11, day, 17, 0),
        );
      }
      // One more day with check in only: present, but no hours yet.
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 5, 9, 0));
      final summary = provider.monthlySummary(employee.id, 2026, 11);
      expect(summary.daysPresent, 4);
      expect(summary.totalHours, closeTo(24.0, 0.001));
      expect(summary.averageHoursPerDay, closeTo(6.0, 0.001));
    });

    test('monthly summary ignores other months', () async {
      final employee = await provider.addEmployee('Test Person', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 10, 30, 9, 0));
      await provider.checkOut(employee.id, at: DateTime(2026, 10, 30, 17, 0));
      final summary = provider.monthlySummary(employee.id, 2026, 11);
      expect(summary.daysPresent, 0);
      expect(summary.totalHours, 0);
    });

    test('today register shows present and absent staff', () async {
      final present = await provider.addEmployee('Present One', 'Tester');
      await provider.addEmployee('Absent One', 'Tester');
      await provider.checkIn(present.id, at: DateTime.now());
      final rows = provider.registerFor(DateTime.now());
      expect(rows.length, 2);
      expect(rows.firstWhere((r) => r.employee.id == present.id).isPresent,
          isTrue);
      expect(rows.firstWhere((r) => r.employee.name == 'Absent One').isPresent,
          isFalse);
    });

    test('CSV export lists records newest first with a header', () async {
      final employee = await provider.addEmployee('Test Person', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 0));
      await provider.checkOut(employee.id, at: DateTime(2026, 11, 9, 17, 0));
      final csv = provider.toCsv();
      final lines = csv.trim().split('\n');
      expect(lines.first,
          'Employee,Role,Date,Check In,Check Out,Hours Worked,Status');
      expect(lines.length, 2);
      expect(lines[1], contains('Test Person'));
      expect(lines[1], contains('2026-11-09'));
      expect(lines[1], contains('8.00'));
    });

    test('late check in after 9:15 AM counts as a late day', () async {
      final employee = await provider.addEmployee('Test Person', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 45));
      await provider.checkOut(employee.id, at: DateTime(2026, 11, 9, 17, 0));
      final summary = provider.monthlySummary(employee.id, 2026, 11);
      expect(summary.lateDays, 1);
    });
  });

  group('AttendanceProvider data reset', () {
    late AttendanceProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = AttendanceProvider();
      await provider.load();
      // Keep the demo seed here so reset behaviour is tested from a
      // realistic starting state.
    });

    test('load seeds 6 demo employees with attendance', () {
      expect(provider.employees.length, 6);
      expect(provider.records, isNotEmpty);
      expect(
        provider.employees.map((e) => e.name),
        contains('Rahim Uddin'),
      );
    });

    test('clear all data empties employees and records and persists',
        () async {
      await provider.clearAllData();
      expect(provider.employees, isEmpty);
      expect(provider.records, isEmpty);
      expect(provider.toCsv().trim().split('\n').length, 1);
      // A fresh provider loading from storage still sees the empty state.
      final reloaded = AttendanceProvider();
      await reloaded.load();
      expect(reloaded.employees, isEmpty);
      expect(reloaded.records, isEmpty);
    });

    test('restore demo data clears custom data and reseeds the demo team',
        () async {
      final custom = await provider.addEmployee('Real Person', 'Manager');
      await provider.checkIn(custom.id, at: DateTime(2026, 11, 9, 9, 0));
      await provider.resetDemoData();
      expect(provider.employees.length, 6);
      expect(provider.records, isNotEmpty);
      expect(
        provider.employees.map((e) => e.name),
        everyElement(isNot('Real Person')),
      );
      expect(
        provider.employees.map((e) => e.name),
        containsAll(['Rahim Uddin', 'Nusrat Jahan', 'Mim Chowdhury']),
      );
      expect(
        provider.records.map((r) => r.employeeId),
        everyElement(isIn(provider.employees.map((e) => e.id))),
      );
    });

    test('clear all data then restore demo data brings the demo team back',
        () async {
      await provider.clearAllData();
      expect(provider.employees, isEmpty);
      await provider.resetDemoData();
      expect(provider.employees.length, 6);
      expect(provider.records, isNotEmpty);
    });
  });
}
