import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:team_attendance/models/app_settings.dart';
import 'package:team_attendance/models/attendance_record.dart';
import 'package:team_attendance/models/employee.dart';
import 'package:team_attendance/state/attendance_provider.dart';
import 'package:team_attendance/utils/attendance_logic.dart' as logic;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings late calculation', () {
    test('default late limit is 9:00 plus 15 minutes grace', () {
      const settings = AppSettings();
      expect(settings.isLate(DateTime(2026, 11, 9, 9, 15)), isFalse);
      expect(settings.isLate(DateTime(2026, 11, 9, 9, 16)), isTrue);
      expect(settings.isLate(DateTime(2026, 11, 9, 9, 45)), isTrue);
      expect(settings.isLate(DateTime(2026, 11, 9, 9, 0)), isFalse);
    });

    test('custom office start and grace move the late limit', () {
      const settings = AppSettings(
        officeStartHour: 8,
        officeStartMinute: 30,
        lateGraceMinutes: 30,
      );
      expect(settings.isLate(DateTime(2026, 11, 9, 9, 0)), isFalse);
      expect(settings.isLate(DateTime(2026, 11, 9, 9, 1)), isTrue);
    });

    test('settings round trip through JSON', () {
      const settings = AppSettings(
        workingDays: {1, 2, 3, 4, 5, 6},
        officeStartHour: 10,
        officeStartMinute: 30,
        lateGraceMinutes: 10,
        standardHoursPerDay: 7.5,
        overtimeRule: 'week',
        overtimeMultiplier: 2,
        currency: 'USD',
        reminderTimes: ['10:00', '18:00'],
      );
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.workingDays, {1, 2, 3, 4, 5, 6});
      expect(restored.officeStartHour, 10);
      expect(restored.standardHoursPerDay, 7.5);
      expect(restored.overtimeRule, 'week');
      expect(restored.overtimeMultiplier, 2);
      expect(restored.currency, 'USD');
      expect(restored.reminderTimes, ['10:00', '18:00']);
    });

    test('old settings JSON without the new keys loads defaults', () {
      final restored = AppSettings.fromJson({});
      expect(restored.officeStartHour, 9);
      expect(restored.lateGraceMinutes, 15);
      expect(restored.currency, 'BDT');
    });
  });

  group('Breaks and worked hours', () {
    test('break minutes are subtracted from worked hours', () {
      final record = AttendanceRecord(
        employeeId: 'e1',
        date: '2026-11-09',
        checkIn: DateTime(2026, 11, 9, 9, 0),
        checkOut: DateTime(2026, 11, 9, 17, 0),
        breakStart: DateTime(2026, 11, 9, 13, 0),
        breakEnd: DateTime(2026, 11, 9, 14, 0),
      );
      expect(record.breakMinutes, 60);
      expect(record.workedHours, closeTo(7.0, 0.001));
    });

    test('incomplete break counts as zero break minutes', () {
      final record = AttendanceRecord(
        employeeId: 'e1',
        date: '2026-11-09',
        checkIn: DateTime(2026, 11, 9, 9, 0),
        checkOut: DateTime(2026, 11, 9, 17, 0),
        breakStart: DateTime(2026, 11, 9, 13, 0),
      );
      expect(record.breakMinutes, 0);
      expect(record.workedHours, closeTo(8.0, 0.001));
    });

    test('break round trips through JSON', () {
      final record = AttendanceRecord(
        employeeId: 'e1',
        date: '2026-11-09',
        checkIn: DateTime(2026, 11, 9, 9, 0),
        checkOut: DateTime(2026, 11, 9, 17, 0),
        breakStart: DateTime(2026, 11, 9, 13, 0),
        breakEnd: DateTime(2026, 11, 9, 13, 30),
        edited: true,
        editReason: 'forgot',
      );
      final restored = AttendanceRecord.fromJson(record.toJson());
      expect(restored.breakMinutes, 30);
      expect(restored.workedHours, closeTo(7.5, 0.001));
      expect(restored.edited, isTrue);
      expect(restored.editReason, 'forgot');
    });
  });

  group('Overtime math', () {
    test('per day rule splits at standard hours', () {
      final split = logic.splitDayHours(10, 8);
      expect(split.regular, 8);
      expect(split.overtime, 2);
      final exact = logic.splitDayHours(8, 8);
      expect(exact.regular, 8);
      expect(exact.overtime, 0);
      final short = logic.splitDayHours(6, 8);
      expect(short.regular, 6);
      expect(short.overtime, 0);
    });

    test('per week rule splits at 48 hours', () {
      final split = logic.splitWeekHours([10, 10, 10, 10, 10]);
      expect(split.regular, 48);
      expect(split.overtime, 2);
      final under = logic.splitWeekHours([8, 8, 8, 8, 8]);
      expect(under.regular, 40);
      expect(under.overtime, 0);
    });

    test('provider splits a long day into regular and overtime', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.load();
      provider.employees = [];
      provider.records = [];
      final employee = await provider.addEmployee('Test Person', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 0));
      await provider.checkOut(
        employee.id,
        at: DateTime(2026, 11, 9, 19, 0),
      );
      final summary = provider.monthlySummary(employee.id, 2026, 11);
      expect(summary.regularHours, closeTo(8.0, 0.001));
      expect(summary.overtimeHours, closeTo(2.0, 0.001));
    });
  });

  group('Payroll math', () {
    test('estimate is regular at rate plus overtime at rate times multiplier',
        () {
      final estimate = logic.payrollEstimate(
        regularHours: 160,
        overtimeHours: 10,
        hourlyRate: 500,
        overtimeMultiplier: 1.5,
      );
      expect(estimate, 160 * 500 + 10 * 500 * 1.5);
    });

    test('zero hourly rate gives a zero estimate', () {
      final estimate = logic.payrollEstimate(
        regularHours: 160,
        overtimeHours: 10,
        hourlyRate: 0,
        overtimeMultiplier: 1.5,
      );
      expect(estimate, 0);
    });

    test('provider monthly summary carries the pay estimate', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.load();
      provider.employees = [];
      provider.records = [];
      final employee = await provider.addEmployee(
        'Paid Person',
        'Tester',
        hourlyRate: 100,
      );
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 0));
      await provider.checkOut(employee.id, at: DateTime(2026, 11, 9, 17, 0));
      final summary = provider.monthlySummary(employee.id, 2026, 11);
      expect(summary.payEstimate, closeTo(800, 0.001));
    });
  });

  group('Edit records and auto check out', () {
    late AttendanceProvider provider;
    late Employee employee;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = AttendanceProvider();
      await provider.load();
      provider.employees = [];
      provider.records = [];
      employee = await provider.addEmployee('Test Person', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 0));
      await provider.checkOut(employee.id, at: DateTime(2026, 11, 9, 17, 0));
    });

    test('edit corrects check out and flags the record with a reason',
        () async {
      final ok = await provider.editRecord(
        employeeId: employee.id,
        day: DateTime(2026, 11, 9),
        checkOut: DateTime(2026, 11, 9, 18, 30),
        reason: 'forgot',
      );
      expect(ok, isTrue);
      final record = provider.recordFor(employee.id, DateTime(2026, 11, 9));
      expect(record?.checkOut, DateTime(2026, 11, 9, 18, 30));
      expect(record?.edited, isTrue);
      expect(record?.editReason, 'forgot');
      expect(record?.workedHours, closeTo(9.5, 0.001));
    });

    test('edit with check out before check in is refused', () async {
      final ok = await provider.editRecord(
        employeeId: employee.id,
        day: DateTime(2026, 11, 9),
        checkOut: DateTime(2026, 11, 9, 8, 0),
        reason: 'late',
      );
      expect(ok, isFalse);
      final record = provider.recordFor(employee.id, DateTime(2026, 11, 9));
      expect(record?.checkOut, DateTime(2026, 11, 9, 17, 0));
      expect(record?.edited, isFalse);
    });

    test('edit with a break outside the working day is refused', () async {
      final ok = await provider.editRecord(
        employeeId: employee.id,
        day: DateTime(2026, 11, 9),
        breakStart: DateTime(2026, 11, 9, 8, 0),
        breakEnd: DateTime(2026, 11, 9, 8, 30),
        reason: 'forgot',
      );
      expect(ok, isFalse);
    });

    test('edit on a missing record is refused', () async {
      final ok = await provider.editRecord(
        employeeId: employee.id,
        day: DateTime(2026, 11, 10),
        checkIn: DateTime(2026, 11, 10, 9, 0),
        reason: 'forgot',
      );
      expect(ok, isFalse);
    });

    test('auto check out closes yesterday at office end and flags auto',
        () async {
      final other = await provider.addEmployee('Open Person', 'Tester');
      await provider.checkIn(other.id, at: DateTime(2026, 11, 12, 9, 0));
      final closed = await provider.autoCheckoutOpenRecords(
        now: DateTime(2026, 11, 13, 10, 0),
      );
      expect(closed, 1);
      final record = provider.recordFor(other.id, DateTime(2026, 11, 12));
      expect(record?.checkOut, DateTime(2026, 11, 12, 17, 0));
      expect(record?.autoCheckout, isTrue);
    });

    test('auto check out leaves a still open today record alone', () async {
      final other = await provider.addEmployee('Open Person', 'Tester');
      await provider.checkIn(other.id, at: DateTime(2026, 11, 13, 9, 0));
      final closed = await provider.autoCheckoutOpenRecords(
        now: DateTime(2026, 11, 13, 10, 0),
      );
      expect(closed, 0);
      final record = provider.recordFor(other.id, DateTime(2026, 11, 13));
      expect(record?.checkOut, isNull);
    });

    test('break start and end on the provider subtract from worked hours',
        () async {
      final other = await provider.addEmployee('Break Person', 'Tester');
      await provider.checkIn(other.id, at: DateTime(2026, 11, 10, 9, 0));
      await provider.startBreak(other.id, at: DateTime(2026, 11, 10, 13, 0));
      await provider.endBreak(other.id, at: DateTime(2026, 11, 10, 14, 0));
      await provider.checkOut(other.id, at: DateTime(2026, 11, 10, 17, 0));
      final record = provider.recordFor(other.id, DateTime(2026, 11, 10));
      expect(record?.workedHours, closeTo(7.0, 0.001));
    });
  });

  group('Employee profiles and archive', () {
    test('v1.0 JSON with only id, name and role still loads', () {
      final employee = Employee.fromJson({
        'id': 'e1',
        'name': 'Old Record',
        'role': 'Staff',
      });
      expect(employee.phone, '');
      expect(employee.hourlyRate, 0);
      expect(employee.employmentType, 'Full-time');
      expect(employee.archived, isFalse);
    });

    test('rich profile round trips through JSON', () {
      const employee = Employee(
        id: 'e9',
        name: 'Full Profile',
        role: 'Developer',
        phone: '01700000000',
        email: 'a@example.com',
        joinDate: '2026-01-15',
        department: 'Engineering',
        hourlyRate: 550,
        employmentType: 'Contract',
      );
      final restored = Employee.fromJson(employee.toJson());
      expect(restored.phone, '01700000000');
      expect(restored.email, 'a@example.com');
      expect(restored.joinDate, '2026-01-15');
      expect(restored.department, 'Engineering');
      expect(restored.hourlyRate, 550);
      expect(restored.employmentType, 'Contract');
    });

    test('archive keeps history but removes the employee from the register',
        () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.load();
      provider.employees = [];
      provider.records = [];
      final employee = await provider.addEmployee('Leaver', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 0));
      final archived = await provider.archiveEmployee(employee.id);
      expect(archived, isTrue);
      expect(provider.activeEmployees, isEmpty);
      expect(provider.archivedEmployees.length, 1);
      expect(provider.registerFor(DateTime(2026, 11, 9)), isEmpty);
      expect(provider.records.length, 1);
      final summary = provider.monthlySummary(employee.id, 2026, 11);
      expect(summary.daysPresent, 1);
      final restored = await provider.unarchiveEmployee(employee.id);
      expect(restored, isTrue);
      expect(provider.activeEmployees.length, 1);
    });

    test('archive of an unknown employee is refused', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.load();
      expect(await provider.archiveEmployee('no-such-id'), isFalse);
    });

    test('updateEmployee edits the profile and keeps history', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.load();
      provider.employees = [];
      provider.records = [];
      final employee = await provider.addEmployee('Old Name', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 0));
      final ok = await provider.updateEmployee(
        employee.copyWith(name: 'New Name', phone: '01800000000'),
      );
      expect(ok, isTrue);
      expect(provider.employees.first.name, 'New Name');
      expect(provider.employees.first.phone, '01800000000');
      expect(provider.records.length, 1);
    });
  });

  group('Report aggregation', () {
    test('team report counts present, absent, late and percent', () {
      const settings = AppSettings();
      const employee = Employee(id: 'e1', name: 'Ana', role: 'Tester');
      final records = [
        AttendanceRecord(
          employeeId: 'e1',
          date: '2026-11-09',
          checkIn: DateTime(2026, 11, 9, 9, 0),
          checkOut: DateTime(2026, 11, 9, 17, 0),
        ),
        AttendanceRecord(
          employeeId: 'e1',
          date: '2026-11-10',
          checkIn: DateTime(2026, 11, 10, 9, 30),
          checkOut: DateTime(2026, 11, 10, 17, 0),
        ),
        AttendanceRecord(
          employeeId: 'e1',
          date: '2026-11-11',
          checkIn: DateTime(2026, 11, 11, 9, 0),
          checkOut: DateTime(2026, 11, 11, 17, 0),
        ),
      ];
      // Working days Mon to Fri up to Fri Nov 13: Nov 2-6 and Nov 9-13 = 10.
      final rows = logic.aggregateTeamReport(
        employees: [employee],
        records: records,
        year: 2026,
        month: 11,
        settings: settings,
        now: DateTime(2026, 11, 13, 12, 0),
      );
      expect(rows.length, 1);
      expect(rows.first.daysPresent, 3);
      expect(rows.first.daysAbsent, 7);
      expect(rows.first.lateDays, 1);
      expect(rows.first.attendancePercent, closeTo(30, 0.001));
      expect(rows.first.totalHours, closeTo(23.5, 0.001));
      expect(rows.first.leaveDays, 0);
    });

    test('monthly summary now reports absent days and percent', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.load();
      provider.employees = [];
      provider.records = [];
      final employee = await provider.addEmployee('Test Person', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 0));
      await provider.checkOut(employee.id, at: DateTime(2026, 11, 9, 17, 0));
      final summary = provider.monthlySummary(employee.id, 2026, 11);
      expect(summary.daysPresent, 1);
      expect(summary.attendancePercent, greaterThan(0));
      expect(
        summary.daysPresent + summary.daysAbsent,
        greaterThanOrEqualTo(1),
      );
    });

    test('working days count respects the settings', () {
      // November 2026 has 30 days; Mon to Fri is 21 days.
      expect(logic.countWorkingDays(2026, 11, {1, 2, 3, 4, 5}), 21);
      // Six day week adds the 4 Saturdays.
      expect(logic.countWorkingDays(2026, 11, {1, 2, 3, 4, 5, 6}), 25);
      // Up to Fri Nov 13 is 10 working days.
      expect(
        logic.countWorkingDays(2026, 11, {1, 2, 3, 4, 5}, upToDay: 13),
        10,
      );
    });
  });

  group('Export data builders', () {
    test('summary sheet rows carry regular, overtime and pay', () {
      const settings = AppSettings();
      const employee = Employee(
        id: 'e1',
        name: 'Ana',
        role: 'Tester',
        hourlyRate: 100,
      );
      final records = [
        AttendanceRecord(
          employeeId: 'e1',
          date: '2026-11-09',
          checkIn: DateTime(2026, 11, 9, 9, 0),
          checkOut: DateTime(2026, 11, 9, 19, 0),
        ),
      ];
      final rows = logic.aggregateTeamReport(
        employees: [employee],
        records: records,
        year: 2026,
        month: 11,
        settings: settings,
        now: DateTime(2026, 11, 13, 12, 0),
      );
      final sheet = logic.buildSummarySheetRows(rows, 'BDT');
      expect(sheet.first.first, 'Employee');
      expect(sheet.length, 2);
      expect(sheet[1][0], 'Ana');
      expect(sheet[1][6], closeTo(10.0, 0.001));
      expect(sheet[1][7], closeTo(8.0, 0.001));
      expect(sheet[1][8], closeTo(2.0, 0.001));
      expect(sheet[1][10], closeTo(1100.0, 0.001));
    });

    test('detail sheet rows list records newest first', () {
      final byId = {
        'e1': const Employee(id: 'e1', name: 'Ana', role: 'Tester'),
      };
      final records = [
        AttendanceRecord(
          employeeId: 'e1',
          date: '2026-11-09',
          checkIn: DateTime(2026, 11, 9, 9, 0),
          checkOut: DateTime(2026, 11, 9, 17, 0),
        ),
        AttendanceRecord(
          employeeId: 'e1',
          date: '2026-11-10',
          checkIn: DateTime(2026, 11, 10, 9, 0),
          checkOut: DateTime(2026, 11, 10, 17, 0),
          breakStart: DateTime(2026, 11, 10, 13, 0),
          breakEnd: DateTime(2026, 11, 10, 14, 0),
        ),
      ];
      final sheet = logic.buildDetailSheetRows(records, byId);
      expect(sheet.first.first, 'Employee');
      expect(sheet.length, 3);
      expect(sheet[1][2], '2026-11-10');
      expect(sheet[1][5], 60);
      expect(sheet[1][6], closeTo(7.0, 0.001));
    });
  });

  group('Backup validation and import', () {
    test('a valid backup passes validation', () {
      final error = logic.validateBackupJson({
        'app': 'team-attendance',
        'version': 2,
        'employees': [
          {'id': 'e1', 'name': 'Ana', 'role': 'Tester'},
        ],
        'records': [
          {'employeeId': 'e1', 'date': '2026-11-09'},
        ],
      });
      expect(error, isNull);
    });

    test('wrong app marker fails validation', () {
      expect(
        logic.validateBackupJson({'app': 'other-app', 'employees': [], 'records': []}),
        isNotNull,
      );
    });

    test('missing lists fail validation', () {
      expect(logic.validateBackupJson({'app': 'team-attendance'}), isNotNull);
    });

    test('employee missing a name fails validation', () {
      expect(
        logic.validateBackupJson({
          'app': 'team-attendance',
          'employees': [
            {'id': 'e1', 'role': 'Tester'},
          ],
          'records': [],
        }),
        isNotNull,
      );
    });

    test('record with a bad date fails validation', () {
      expect(
        logic.validateBackupJson({
          'app': 'team-attendance',
          'employees': [],
          'records': [
            {'employeeId': 'e1', 'date': 'Nov 9'},
          ],
        }),
        isNotNull,
      );
    });

    test('export then import round trips the data', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.load();
      provider.employees = [];
      provider.records = [];
      final employee = await provider.addEmployee(
        'Backup Person',
        'Tester',
        hourlyRate: 250,
      );
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 0));
      await provider.checkOut(employee.id, at: DateTime(2026, 11, 9, 17, 0));
      final json = provider.exportBackupJson();

      final fresh = AttendanceProvider();
      await fresh.load();
      fresh.employees = [];
      fresh.records = [];
      final error = await fresh.importBackupJson(json);
      expect(error, isNull);
      expect(fresh.employees.length, 1);
      expect(fresh.employees.first.name, 'Backup Person');
      expect(fresh.employees.first.hourlyRate, 250);
      expect(fresh.records.length, 1);
    });

    test('invalid import returns an error and keeps current data', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.load();
      provider.employees = [];
      provider.records = [];
      await provider.addEmployee('Keep Me', 'Tester');
      final error = await provider.importBackupJson('{"app": "wrong"}');
      expect(error, isNotNull);
      expect(provider.employees.length, 1);
      expect(provider.employees.first.name, 'Keep Me');
      final badJson = await provider.importBackupJson('not json at all');
      expect(badJson, isNotNull);
      expect(provider.employees.length, 1);
    });
  });

  group('Settings persistence', () {
    test('updated settings survive a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.load();
      await provider.updateSettings(
        const AppSettings(
          officeStartHour: 8,
          officeStartMinute: 30,
          lateGraceMinutes: 10,
          currency: 'USD',
        ),
      );
      final reloaded = AttendanceProvider();
      await reloaded.load();
      expect(reloaded.settings.officeStartHour, 8);
      expect(reloaded.settings.officeStartMinute, 30);
      expect(reloaded.settings.lateGraceMinutes, 10);
      expect(reloaded.settings.currency, 'USD');
    });

    test('late counting follows saved settings, not 9:15', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AttendanceProvider();
      await provider.load();
      provider.employees = [];
      provider.records = [];
      await provider.updateSettings(
        const AppSettings(
          officeStartHour: 10,
          officeStartMinute: 0,
          lateGraceMinutes: 0,
        ),
      );
      final employee = await provider.addEmployee('Test Person', 'Tester');
      await provider.checkIn(employee.id, at: DateTime(2026, 11, 9, 9, 45));
      await provider.checkOut(employee.id, at: DateTime(2026, 11, 9, 17, 0));
      final summary = provider.monthlySummary(employee.id, 2026, 11);
      expect(summary.lateDays, 0);
    });
  });
}
