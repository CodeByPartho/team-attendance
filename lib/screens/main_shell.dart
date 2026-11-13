import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/attendance_provider.dart';
import 'employees_screen.dart';
import 'export_screen.dart';
import 'history_screen.dart';
import 'today_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<Widget> _pages = [
    TodayScreen(),
    EmployeesScreen(),
    HistoryScreen(),
    ExportScreen(),
  ];

  Future<void> _showResetDialog(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset data?'),
          content: const Text(
            'Clear all data removes every employee and attendance record, '
            'so you start with an empty team. Restore demo data does the '
            'same, then brings back the 6 person demo team with this week '
            'of attendance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'clear'),
              child: const Text('Clear all data'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'demo'),
              child: const Text('Restore demo data'),
            ),
          ],
        );
      },
    );
    if (choice == null || !context.mounted) return;
    final provider = context.read<AttendanceProvider>();
    if (choice == 'clear') {
      await provider.clearAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared')),
        );
      }
    } else if (choice == 'demo') {
      await provider.resetDemoData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo data restored')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final today = provider.registerFor(DateTime.now());
    final present = today.where((row) => row.isPresent).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset data',
            onPressed: () => _showResetDialog(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$present/${today.length} present today',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Employees',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.file_download_outlined),
            selectedIcon: Icon(Icons.file_download),
            label: 'Export',
          ),
        ],
      ),
    );
  }
}
