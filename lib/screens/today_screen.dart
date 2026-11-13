import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_record.dart';
import '../state/attendance_provider.dart';
import '../utils/format.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final now = DateTime.now();
    final rows = provider.registerFor(now);
    final present = rows.where((r) => r.isPresent).length;
    final checkedOut = rows.where((r) => r.isCheckedOut).length;

    if (!provider.loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          formatDateLong(now),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Tap Check In when you arrive, Check Out when you leave. '
          'Times are recorded on this device.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatChip(label: 'Present', value: '$present'),
            const SizedBox(width: 8),
            _StatChip(label: 'Checked out', value: '$checkedOut'),
            const SizedBox(width: 8),
            _StatChip(label: 'Absent', value: '${rows.length - present}'),
          ],
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No employees yet. Add your team from the Employees tab.',
              ),
            ),
          ),
        for (final row in rows)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          row.employee.name.isEmpty
                              ? '?'
                              : row.employee.name[0].toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.employee.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              row.employee.role,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(record: row.record),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeCell(
                          label: 'Check in',
                          value: formatTime(row.record?.checkIn),
                        ),
                      ),
                      Expanded(
                        child: _TimeCell(
                          label: 'Check out',
                          value: formatTime(row.record?.checkOut),
                        ),
                      ),
                      Expanded(
                        child: _TimeCell(
                          label: 'Worked',
                          value: row.record == null
                              ? '--'
                              : formatHours(row.record!.workedHours),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: row.isPresent
                              ? null
                              : () async {
                                  await context
                                      .read<AttendanceProvider>()
                                      .checkIn(row.employee.id);
                                },
                          icon: const Icon(Icons.login),
                          label: const Text('Check In'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              row.isPresent && !row.isCheckedOut
                                  ? () async {
                                      await context
                                          .read<AttendanceProvider>()
                                          .checkOut(row.employee.id);
                                    }
                                  : null,
                          icon: const Icon(Icons.logout),
                          label: const Text('Check Out'),
                        ),
                      ),
                    ],
                  ),
                  if (row.isPresent && !row.isCheckedOut) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: row.record?.breakStart == null
                                ? () async {
                                    await context
                                        .read<AttendanceProvider>()
                                        .startBreak(row.employee.id);
                                  }
                                : null,
                            icon: const Icon(Icons.coffee),
                            label: const Text('Start Break'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: row.record?.breakStart != null &&
                                    row.record?.breakEnd == null
                                ? () async {
                                    await context
                                        .read<AttendanceProvider>()
                                        .endBreak(row.employee.id);
                                  }
                                : null,
                            icon: const Icon(Icons.coffee_outlined),
                            label: Text(
                              row.record?.breakStart != null &&
                                      row.record?.breakEnd == null
                                  ? 'End Break'
                                  : row.record?.breakMinutes != null &&
                                          row.record!.breakMinutes > 0
                                      ? 'Break ${row.record!.breakMinutes}m'
                                      : 'End Break',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.record});

  final AttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    final status = record?.status ?? 'Absent';
    final color = status == 'Present'
        ? Theme.of(context).colorScheme.primary
        : status == 'Checked out'
            ? Colors.blueGrey
            : Colors.orange;
    return Chip(
      label: Text(status),
      backgroundColor: color.withValues(alpha: 0.18),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      side: BorderSide.none,
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
