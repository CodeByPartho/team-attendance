import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/attendance_provider.dart';
import '../utils/export_files.dart';
import '../utils/format.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String? _filterEmployeeId;
  DateTime? _filterFrom;
  DateTime? _filterTo;
  DateTime _reportMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _shareFile(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: name),
    );
  }

  Future<void> _shareTextFile(String name, String text) async {
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'File sharing is limited in the browser demo, so the backup '
              'was copied to the clipboard instead.',
            ),
          ),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(text);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: name),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportPdf(AttendanceProvider provider) async {
    final rows = provider.teamMonthlyReport(
      _reportMonth.year,
      _reportMonth.month,
    );
    final total = rows.fold<double>(0, (sum, r) => sum + r.payEstimate);
    final bytes = await buildMonthlyPdfBytes(
      title: 'Team Attendance - ${formatMonthYear(_reportMonth)}',
      rows: rows,
      currency: provider.settings.currency,
      teamTotalPay: total,
    );
    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'team-attendance-${_reportMonth.year}-${_reportMonth.month.toString().padLeft(2, '0')}.pdf',
      );
      return;
    }
    await _shareFile(
      'team-attendance-${_reportMonth.year}-${_reportMonth.month.toString().padLeft(2, '0')}.pdf',
      bytes,
    );
  }

  Future<void> _exportXlsx(AttendanceProvider provider) async {
    final bytes = buildMonthlyXlsxBytes(
      summaryRows: provider.summarySheetRows(
        _reportMonth.year,
        _reportMonth.month,
      ),
      detailRows: provider.detailSheetRows(),
    );
    await _shareFile(
      'team-attendance-${_reportMonth.year}-${_reportMonth.month.toString().padLeft(2, '0')}.xlsx',
      bytes,
    );
  }

  Future<void> _exportBackup(AttendanceProvider provider) async {
    final json = provider.exportBackupJson();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    await _shareTextFile('team-attendance-backup-$stamp.json', json);
    if (!kIsWeb) _showMessage('Backup file ready to share or save');
  }

  Future<void> _importBackup(AttendanceProvider provider) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked.isEmpty) return;
    if (!mounted) return;
    final file = picked.first;
    Uint8List? bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) {
      _showMessage('Could not read that file.');
      return;
    }
    if (!mounted) return;
    final text = String.fromCharCodes(bytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import backup?'),
          content: const Text(
            'This replaces every employee, attendance record and setting '
            'with the backup. The current data will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace and import'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final error = await provider.importBackupJson(text);
    if (!mounted) return;
    _showMessage(
      error ?? 'Backup imported: ${provider.employees.length} employees, '
          '${provider.records.length} records.',
    );
  }

  Future<void> _pickFilterDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _filterFrom = picked;
        } else {
          _filterTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final csv = provider.toCsv(
      from: _filterFrom,
      to: _filterTo,
      employeeId: _filterEmployeeId,
    );
    final rowCount = provider.records.length;
    final employees = provider.employees;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Monthly reports', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'PDF and spreadsheet files for ${formatMonthYear(_reportMonth)}. '
          'They open in the native share sheet, so you can save or send them.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _reportMonth = DateTime(
                    _reportMonth.year,
                    _reportMonth.month - 1,
                  );
                });
              },
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
            ),
            Expanded(
              child: Text(
                formatMonthYear(_reportMonth),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _reportMonth = DateTime(
                    _reportMonth.year,
                    _reportMonth.month + 1,
                  );
                });
              },
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: rowCount == 0
                    ? null
                    : () async {
                        try {
                          await _exportPdf(provider);
                        } catch (e) {
                          _showMessage('Could not make the PDF: $e');
                        }
                      },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Monthly PDF'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: rowCount == 0
                    ? null
                    : () async {
                        try {
                          await _exportXlsx(provider);
                        } catch (e) {
                          _showMessage('Could not make the file: $e');
                        }
                      },
                icon: const Icon(Icons.table_chart),
                label: const Text('Monthly .xlsx'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('CSV Export', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '$rowCount attendance rows, newest first. Filter by date or '
          'employee, then copy the text or paste it into a spreadsheet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickFilterDate(true),
                child: Text(
                  _filterFrom == null
                      ? 'From date'
                      : 'From ${_filterFrom!.toIso8601String().substring(0, 10)}',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickFilterDate(false),
                child: Text(
                  _filterTo == null
                      ? 'To date'
                      : 'To ${_filterTo!.toIso8601String().substring(0, 10)}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _filterEmployeeId,
          decoration: const InputDecoration(labelText: 'Employee (all)'),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All employees'),
            ),
            for (final e in employees)
              DropdownMenuItem(value: e.id, child: Text(e.name)),
          ],
          onChanged: (value) {
            setState(() => _filterEmployeeId = value);
          },
        ),
        if (_filterFrom != null ||
            _filterTo != null ||
            _filterEmployeeId != null)
          TextButton(
            onPressed: () {
              setState(() {
                _filterFrom = null;
                _filterTo = null;
                _filterEmployeeId = null;
              });
            },
            child: const Text('Clear filters'),
          ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 20),
        Text('Backup and restore', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'Export all employees, records and settings as one JSON file. '
          'Import it back on any device to restore the same data. Import '
          'checks the file first and asks before replacing anything.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _exportBackup(provider),
                icon: const Icon(Icons.backup),
                label: const Text('Export backup'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _importBackup(provider),
                icon: const Icon(Icons.restore),
                label: const Text('Import backup'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
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
