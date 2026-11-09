import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final dayRecords = provider.historyFor(_selected);
    final present = dayRecords.where((r) => r.isPresent).length;
    final absentCount = provider.employees.length - present;

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
          '$present present, $absentCount absent',
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
                  subtitle: Text(employee.role),
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
                ),
              );
            },
          ),
      ],
    );
  }
}
