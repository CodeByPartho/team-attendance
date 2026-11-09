import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'state/attendance_provider.dart';

void main() {
  runApp(const TeamAttendanceApp());
}

class TeamAttendanceApp extends StatelessWidget {
  const TeamAttendanceApp({super.key});

  static const Color accent = Color(0xFF39FF88);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AttendanceProvider()..load(),
      child: MaterialApp(
        title: 'Team Attendance',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const MainShell(),
      ),
    );
  }
}
