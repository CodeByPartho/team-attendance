import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_record.dart';
import '../models/employee.dart';
import '../state/attendance_provider.dart';
import '../utils/format.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selected = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selected = picked);
    }
  }

  /// Tap a row to correct a wrong punch: change check in or out, add a
  /// break, and record a reason. The record is flagged as edited.
  Future<void> _showEditDialog(
    BuildContext context,
    AttendanceProvider provider,
    Employee employee,
    AttendanceRecord record,
  ) async {
    final day = DateTime(
      _selected.year,
      _selected.month,
      _selected.day,
    );
    var checkIn = record.checkIn == null
        ? TimeOfDay.now()
        : TimeOfDay.fromDateTime(record.checkIn!);
    var checkOut = record.checkOut == null
        ? null
        : TimeOfDay.fromDateTime(record.checkOut!);
    var breakStart = record.breakStart == null
        ? null
        : TimeOfDay.fromDateTime(record.breakStart!);
    var breakEnd = record.breakEnd == null
        ? null
        : TimeOfDay.fromDateTime(record.breakEnd!);
    var reason = record.editReason ?? 'forgot';
    var clearBreak = false;
    const reasons = ['forgot', 'late', 'half day', 'other'];

    DateTime atTime(TimeOfDay time) => DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        );

    Future<TimeOfDay?> pickTime(TimeOfDay initial) async {
      return showTimePicker(context: context, initialTime: initial);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit ${employee.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatDateLong(day)),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Check in'),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          final picked = await pickTime(checkIn);
                          if (picked != null) {
                            setDialogState(() => checkIn = picked);
                          }
                        },
                        child: Text(checkIn.format(context)),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Check out'),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          final picked = await pickTime(
                            checkOut ?? const TimeOfDay(hour: 17, minute: 30),
                          );
                          if (picked != null) {
                            setDialogState(() => checkOut = picked);
                          }
                        },
                        child: Text(
                          checkOut?.format(context) ?? 'Not set',
                        ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Break start'),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          final picked = await pickTime(
                            breakStart ?? const TimeOfDay(hour: 13, minute: 0),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              breakStart = picked;
                              clearBreak = false;
                            });
                          }
                        },
                        child: Text(
                          breakStart?.format(context) ?? 'Not set',
                        ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Break end'),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          final picked = await pickTime(
                            breakEnd ?? const TimeOfDay(hour: 14, minute: 0),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              breakEnd = picked;
                              clearBreak = false;
                            });
                          }
                        },
                        child: Text(
                          breakEnd?.format(context) ?? 'Not set',
                        ),
                      ),
                    ),
                    if (record.breakStart != null ||
                        record.breakEnd != null)
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            breakStart = null;
                            breakEnd = null;
                            clearBreak = true;
                          });
                        },
                        child: const Text('Remove break'),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          reasons.contains(reason) ? reason : 'other',
                      decoration: const InputDecoration(
                        labelText: 'Reason for edit',
                      ),
                      items: [
                        for (final r in reasons)
                          DropdownMenuItem(value: r, child: Text(r)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => reason = value);
                        }
                      },
                    ),
                    if (record.edited)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('This record was edited before.'),
                      ),
                    if (record.autoCheckout)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Check out was filled in automatically at office '
                          'end time.',
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true || !context.mounted) return;
    final ok = await provider.editRecord(
      employeeId: employee.id,
      day: day,
      checkIn: atTime(checkIn),
      checkOut: checkOut == null ? null : atTime(checkOut!),
      breakStart: breakStart == null ? null : atTime(breakStart!),
      breakEnd: breakEnd == null ? null : atTime(breakEnd!),
      clearBreak: clearBreak,
      reason: reason,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Record updated'
                : 'Could not save: check times are impossible.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final dayRecords = provider.historyFor(_selected);
    final present = dayRecords.where((r) => r.isPresent).length;
    final absentCount = provider.activeEmployees.length - present;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                formatDateLong(_selected),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Pick a date',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$present present, $absentCount absent. Tap a row to correct it.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (dayRecords.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No attendance recorded for this date.'),
            ),
          ),
        for (final record in dayRecords)
          Builder(
            builder: (context) {
              final employee = provider.employees.firstWhere(
                (e) => e.id == record.employeeId,
                orElse: () => const Employee(
                  id: 'unknown',
                  name: 'Unknown',
                  role: '',
                ),
              );
              final flags = [
                if (record.edited) 'Edited',
                if (record.autoCheckout) 'Auto check-out',
                if (record.breakMinutes > 0)
                  'Break ${record.breakMinutes}m',
              ].join(' - ');
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      employee.name.isEmpty
                          ? '?'
                          : employee.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(employee.name),
                  subtitle: Text(
                    flags.isEmpty ? employee.role : flags,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${formatTime(record.checkIn)} - '
                        '${formatTime(record.checkOut)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        record.checkOut == null
                            ? record.status
                            : formatHours(record.workedHours),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  onTap: () => _showEditDialog(
                    context,
                    provider,
                    employee,
                    record,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
