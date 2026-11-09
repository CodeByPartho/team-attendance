import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/attendance_provider.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final csv = provider.toCsv();
    final rowCount = provider.records.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'CSV Export',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '$rowCount attendance rows, newest first. Copy the text below '
          'and paste it into a spreadsheet or save it as a .csv file.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: rowCount == 0
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CSV copied to clipboard')),
                    );
                  }
                },
          icon: const Icon(Icons.copy),
          label: const Text('Copy CSV'),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              csv,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Reset demo data?'),
                  content: const Text(
                    'This deletes all employees and attendance records '
                    'and restores the 6 person demo team with this week '
                    'of attendance.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                );
              },
            );
            if (confirmed == true && context.mounted) {
              await context.read<AttendanceProvider>().resetDemoData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo data restored')),
                );
              }
            }
          },
          icon: const Icon(Icons.restore),
          label: const Text('Reset Demo Data'),
        ),
      ],
    );
  }
}
