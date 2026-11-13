import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../state/attendance_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _currencies = ['BDT', 'USD', 'INR', 'EUR', 'GBP'];

  late Set<int> _workingDays;
  late TimeOfDay _officeStart;
  late TextEditingController _graceController;
  late TextEditingController _standardHoursController;
  late TextEditingController _multiplierController;
  late String _overtimeRule;
  late String _currency;
  late TextEditingController _checkInReminderController;
  late TextEditingController _checkOutReminderController;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final settings = context.read<AttendanceProvider>().settings;
    _workingDays = {...settings.workingDays};
    _officeStart = TimeOfDay(
      hour: settings.officeStartHour,
      minute: settings.officeStartMinute,
    );
    _graceController =
        TextEditingController(text: '${settings.lateGraceMinutes}');
    _standardHoursController = TextEditingController(
      text: settings.standardHoursPerDay.toString(),
    );
    _multiplierController = TextEditingController(
      text: settings.overtimeMultiplier.toString(),
    );
    _overtimeRule = settings.overtimeRule;
    _currency = _currencies.contains(settings.currency)
        ? settings.currency
        : 'BDT';
    final reminders = settings.reminderTimes;
    _checkInReminderController = TextEditingController(
      text: reminders.isNotEmpty ? reminders[0] : '09:00',
    );
    _checkOutReminderController = TextEditingController(
      text: reminders.length > 1 ? reminders[1] : '17:30',
    );
    _loaded = true;
  }

  @override
  void dispose() {
    _graceController.dispose();
    _standardHoursController.dispose();
    _multiplierController.dispose();
    _checkInReminderController.dispose();
    _checkOutReminderController.dispose();
    super.dispose();
  }

  Future<void> _pickOfficeStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _officeStart,
    );
    if (picked != null) setState(() => _officeStart = picked);
  }

  Future<void> _save() async {
    final grace = int.tryParse(_graceController.text.trim());
    final standardHours = double.tryParse(_standardHoursController.text.trim());
    final multiplier = double.tryParse(_multiplierController.text.trim());
    if (grace == null || grace < 0 || grace > 120) {
      _showError('Late grace must be 0 to 120 minutes.');
      return;
    }
    if (standardHours == null || standardHours <= 0 || standardHours > 24) {
      _showError('Standard hours per day must be 0 to 24.');
      return;
    }
    if (multiplier == null || multiplier < 1 || multiplier > 5) {
      _showError('Overtime multiplier must be 1 to 5.');
      return;
    }
    if (_workingDays.isEmpty) {
      _showError('Pick at least one working day.');
      return;
    }
    final timePattern = RegExp(r'^\d{2}:\d{2}$');
    final inReminder = _checkInReminderController.text.trim();
    final outReminder = _checkOutReminderController.text.trim();
    if (!timePattern.hasMatch(inReminder) ||
        !timePattern.hasMatch(outReminder)) {
      _showError('Reminder times must look like 09:00.');
      return;
    }
    final settings = AppSettings(
      workingDays: _workingDays,
      officeStartHour: _officeStart.hour,
      officeStartMinute: _officeStart.minute,
      lateGraceMinutes: grace,
      standardHoursPerDay: standardHours,
      overtimeRule: _overtimeRule,
      overtimeMultiplier: multiplier,
      currency: _currency,
      reminderTimes: [inReminder, outReminder],
    );
    await context.read<AttendanceProvider>().updateSettings(settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lateLimit = AppSettings(
      officeStartHour: _officeStart.hour,
      officeStartMinute: _officeStart.minute,
      lateGraceMinutes: int.tryParse(_graceController.text.trim()) ?? 15,
    ).lateLabel;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
          'These settings apply to the whole team. Late is counted from '
          'office start plus grace, and overtime from standard hours.',
        ),
        const SizedBox(height: 16),
        Text('Working days', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 1; i <= 7; i++)
              FilterChip(
                label: Text(_dayNames[i - 1]),
                selected: _workingDays.contains(i),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _workingDays.add(i);
                    } else {
                      _workingDays.remove(i);
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Office start time'),
          subtitle: Text(
            'Late means a check in $lateLimit',
          ),
          trailing: FilledButton.tonal(
            onPressed: _pickOfficeStart,
            child: Text(_officeStart.format(context)),
          ),
        ),
        TextField(
          controller: _graceController,
          decoration: const InputDecoration(
            labelText: 'Late grace (minutes after office start)',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _standardHoursController,
          decoration: const InputDecoration(
            labelText: 'Standard hours per day',
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _overtimeRule,
          decoration: const InputDecoration(labelText: 'Overtime rule'),
          items: const [
            DropdownMenuItem(
              value: 'day',
              child: Text('Over standard hours in a day'),
            ),
            DropdownMenuItem(
              value: 'week',
              child: Text('Over 48 hours in a week'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _overtimeRule = value);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _multiplierController,
          decoration: const InputDecoration(
            labelText: 'Overtime pay multiplier',
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: const InputDecoration(labelText: 'Currency'),
          items: [
            for (final code in _currencies)
              DropdownMenuItem(value: code, child: Text(code)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _currency = value);
          },
        ),
        const SizedBox(height: 16),
        Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Reminder times are stored with settings. The app does not send '
          'notifications yet.',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _checkInReminderController,
                decoration: const InputDecoration(
                  labelText: 'Check in reminder (HH:mm)',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _checkOutReminderController,
                decoration: const InputDecoration(
                  labelText: 'Check out reminder (HH:mm)',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Save Settings'),
        ),
      ],
    );
  }
}
