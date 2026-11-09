import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/employee.dart';
import '../state/attendance_provider.dart';
import '../utils/format.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final now = DateTime.now();
    return Scaffold(
      body: provider.employees.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No employees yet. Tap the + button to add your first team member.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.employees.length,
              itemBuilder: (context, index) {
                final employee = provider.employees[index];
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
                    subtitle: Text(employee.role),
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
                    onTap: () => _showSummary(context, provider, employee),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmployee(context),
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
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(employee.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Role: ${employee.role}'),
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
                label: 'Total hours',
                value: formatHours(summary.totalHours),
              ),
              _SummaryRow(
                label: 'Average per day',
                value: formatHours(summary.averageHoursPerDay),
              ),
              _SummaryRow(
                label: 'Late arrivals (after 9:15 AM)',
                value: '${summary.lateDays}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Remove employee?'),
                      content: Text(
                        'This also deletes all attendance records for '
                        '${employee.name}.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Remove'),
                        ),
                      ],
                    );
                  },
                );
                if (confirmed == true && context.mounted) {
                  await provider.removeEmployee(employee.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Remove'),
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

  Future<void> _showAddEmployee(BuildContext context) async {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Employee'),
          content: Form(
            key: formKey,
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
              ],
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
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (added == true && context.mounted) {
      await context.read<AttendanceProvider>().addEmployee(
            nameController.text,
            roleController.text,
          );
    }
    nameController.dispose();
    roleController.dispose();
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
