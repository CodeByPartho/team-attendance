import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/attendance_provider.dart';
import '../utils/format.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final rows = provider.teamMonthlyReport(_month.year, _month.month);
    final teamTotalPay = rows.fold<double>(0, (sum, r) => sum + r.payEstimate);
    final teamHours = rows.fold<double>(0, (sum, r) => sum + r.totalHours);
    final lateRows = rows.where((r) => r.lateDays > 0).toList();
    final maxHours = rows.fold<double>(
      0,
      (max, r) => r.totalHours > max ? r.totalHours : max,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _shiftMonth(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
            ),
            Expanded(
              child: Text(
                formatMonthYear(_month),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: () => _shiftMonth(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatChip(
              label: 'Team hours',
              value: formatHours(teamHours),
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Pay estimate (${provider.settings.currency})',
              value: teamTotalPay.toStringAsFixed(0),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Pay figures are estimates from recorded hours and hourly rates, '
          'not legal payslips. Unpaid leave is 0 because leave is not '
          'tracked yet.',
        ),
        const SizedBox(height: 16),
        Text('Hours per employee', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No employees yet.'),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    maxY: (maxHours * 1.15).ceilToDouble(),
                    barGroups: [
                      for (var i = 0; i < rows.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: rows[i].totalHours,
                              color: Theme.of(context).colorScheme.primary,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        ),
                    ],
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) => Text(
                            '${value.toInt()}h',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= rows.length) {
                              return const SizedBox.shrink();
                            }
                            final firstName =
                                rows[index].employee.name.split(' ').first;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                firstName,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text('Team monthly table', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No data for this month.'),
            ),
          )
        else
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Employee')),
                  DataColumn(label: Text('Present'), numeric: true),
                  DataColumn(label: Text('Absent'), numeric: true),
                  DataColumn(label: Text('Leave'), numeric: true),
                  DataColumn(label: Text('Late'), numeric: true),
                  DataColumn(label: Text('Hours'), numeric: true),
                  DataColumn(label: Text('Attend %'), numeric: true),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(row.employee.name)),
                        DataCell(Text('${row.daysPresent}')),
                        DataCell(Text('${row.daysAbsent}')),
                        DataCell(Text('${row.leaveDays}')),
                        DataCell(Text('${row.lateDays}')),
                        DataCell(
                          Text(
                            '${formatHours(row.regularHours)} + '
                            '${formatHours(row.overtimeHours)} OT',
                          ),
                        ),
                        DataCell(
                          Text('${row.attendancePercent.toStringAsFixed(0)}%'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text('Late days', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (lateRows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nobody was late this month.'),
            ),
          )
        else
          for (final row in lateRows)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(row.employee.name),
                trailing: Text(
                  '${row.lateDays} late day${row.lateDays == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
