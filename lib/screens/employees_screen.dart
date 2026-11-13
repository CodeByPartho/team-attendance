import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/employee.dart';
import '../state/attendance_provider.dart';
import '../utils/format.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final now = DateTime.now();
    final list = _showArchived
        ? provider.archivedEmployees
        : provider.activeEmployees;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tap an employee for their monthly summary and pay '
                    'estimate.',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _showArchived = !_showArchived);
                  },
                  child: Text(
                    _showArchived
                        ? 'Show active'
                        : 'Archived (${provider.archivedEmployees.length})',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _showArchived
                            ? 'No archived employees. Archiving keeps '
                                'history but removes someone from the today '
                                'register.'
                            : 'No employees yet. Tap the + button to add '
                                'your first team member.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final employee = list[index];
                      final summary = provider.monthlySummary(
                        employee.id,
                        now.year,
                        now.month,
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
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
                            employee.department.isEmpty
                                ? employee.role
                                : '${employee.role} - ${employee.department}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${summary.daysPresent} days',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${formatHours(summary.totalHours)} this month',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          onTap: () =>
                              _showSummary(context, provider, employee),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEmployeeForm(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ),
    );
  }

  void _showSummary(
    BuildContext context,
    AttendanceProvider provider,
    Employee employee,
  ) {
    final now = DateTime.now();
    final summary = provider.monthlySummary(
      employee.id,
      now.year,
      now.month,
    );
    final currency = provider.settings.currency;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(employee.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Role: ${employee.role}'),
                if (employee.department.isNotEmpty)
                  Text('Department: ${employee.department}'),
                if (employee.phone.isNotEmpty)
                  Text('Phone: ${employee.phone}'),
                if (employee.email.isNotEmpty)
                  Text('Email: ${employee.email}'),
                if (employee.joinDate != null)
                  Text('Joined: ${employee.joinDate}'),
                Text('Type: ${employee.employmentType}'),
                Text(
                  'Hourly rate: ${employee.hourlyRate.toStringAsFixed(0)} '
                  '$currency',
                ),
                const SizedBox(height: 12),
                Text(
                  formatMonthYear(now),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  label: 'Days present',
                  value:
                      '${summary.daysPresent} of ${summary.daysInMonthSoFar} days so far',
                ),
                _SummaryRow(
                  label: 'Days absent',
                  value: '${summary.daysAbsent}',
                ),
                _SummaryRow(
                  label: 'Attendance',
                  value:
                      '${summary.attendancePercent.toStringAsFixed(0)}%',
                ),
                _SummaryRow(
                  label: 'Total hours',
                  value: formatHours(summary.totalHours),
                ),
                _SummaryRow(
                  label: 'Regular hours',
                  value: formatHours(summary.regularHours),
                ),
                _SummaryRow(
                  label: 'Overtime hours',
                  value: formatHours(summary.overtimeHours),
                ),
                _SummaryRow(
                  label: 'Average per day',
                  value: formatHours(summary.averageHoursPerDay),
                ),
                _SummaryRow(
                  label:
                      'Late arrivals (${provider.settings.lateLabel})',
                  value: '${summary.lateDays}',
                ),
                const Divider(),
                _SummaryRow(
                  label: 'Pay estimate',
                  value:
                      '${summary.payEstimate.toStringAsFixed(0)} $currency',
                ),
                const Text(
                  'Estimate from recorded hours and hourly rate, not a '
                  'legal payslip. Unpaid leave is 0.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showEmployeeForm(context, existing: employee);
              },
              child: const Text('Edit'),
            ),
            if (employee.archived)
              TextButton(
                onPressed: () async {
                  await provider.unarchiveEmployee(employee.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Restore'),
              )
            else
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Archive employee?'),
                        content: Text(
                          '${employee.name} will leave the today register, '
                          'but all attendance records are kept.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Archive'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirmed == true && context.mounted) {
                    await provider.archiveEmployee(employee.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Archive'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// One form for adding and editing. Editing reuses the add form and
  /// keeps the employee id and history.
  Future<void> _showEmployeeForm(
    BuildContext context, {
    Employee? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final roleController = TextEditingController(text: existing?.role ?? '');
    final phoneController =
        TextEditingController(text: existing?.phone ?? '');
    final emailController =
        TextEditingController(text: existing?.email ?? '');
    final joinDateController =
        TextEditingController(text: existing?.joinDate ?? '');
    final departmentController =
        TextEditingController(text: existing?.department ?? '');
    final rateController = TextEditingController(
      text: existing == null ? '' : existing.hourlyRate.toStringAsFixed(0),
    );
    var employmentType = existing?.employmentType ?? 'Full-time';
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Employee' : 'Edit Employee'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Enter a name'
                            : null,
                  ),
                  TextFormField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: 'Role (for example, Developer)',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  TextFormField(
                    controller: joinDateController,
                    decoration: const InputDecoration(
                      labelText: 'Join date (yyyy-MM-dd, optional)',
                    ),
                  ),
                  TextFormField(
                    controller: departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  TextFormField(
                    controller: rateController,
                    decoration: const InputDecoration(
                      labelText: 'Hourly rate (in team currency)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: employmentType,
                    decoration: const InputDecoration(
                      labelText: 'Employment type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Full-time',
                        child: Text('Full-time'),
                      ),
                      DropdownMenuItem(
                        value: 'Part-time',
                        child: Text('Part-time'),
                      ),
                      DropdownMenuItem(
                        value: 'Contract',
                        child: Text('Contract'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) employmentType = value;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
    if (saved == true && context.mounted) {
      final provider = context.read<AttendanceProvider>();
      final rate = double.tryParse(rateController.text.trim()) ?? 0;
      final joinDate = joinDateController.text.trim();
      if (existing == null) {
        await provider.addEmployee(
          nameController.text,
          roleController.text,
          phone: phoneController.text,
          email: emailController.text,
          joinDate: joinDate.isEmpty ? null : joinDate,
          department: departmentController.text,
          hourlyRate: rate,
          employmentType: employmentType,
        );
      } else {
        await provider.updateEmployee(
          existing.copyWith(
            name: nameController.text.trim(),
            role: roleController.text.trim().isEmpty
                ? 'Staff'
                : roleController.text.trim(),
            phone: phoneController.text.trim(),
            email: emailController.text.trim(),
            joinDate: joinDate.isEmpty ? null : joinDate,
            department: departmentController.text.trim(),
            hourlyRate: rate,
            employmentType: employmentType,
          ),
        );
      }
    }
    nameController.dispose();
    roleController.dispose();
    phoneController.dispose();
    emailController.dispose();
    joinDateController.dispose();
    departmentController.dispose();
    rateController.dispose();
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
