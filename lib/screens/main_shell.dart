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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final today = provider.registerFor(DateTime.now());
    final present = today.where((row) => row.isPresent).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Attendance'),
        actions: [
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
