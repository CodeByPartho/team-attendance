import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/attendance_logic.dart';

/// Builds real export files from the data builders in attendance_logic.
/// These functions only turn rows into bytes; the screens handle saving
/// and sharing the file.

CellValue? _toCell(Object? value) {
  if (value == null) return null;
  if (value is int) return IntCellValue(value);
  if (value is double) return DoubleCellValue(value);
  return TextCellValue(value.toString());
}

/// Monthly .xlsx bytes with a Summary sheet and a Detail sheet.
List<int> buildMonthlyXlsxBytes({
  required List<List<Object?>> summaryRows,
  required List<List<Object?>> detailRows,
}) {
  final excel = Excel.createExcel();
  final summary = excel['Summary'];
  for (final row in summaryRows) {
    summary.appendRow(row.map(_toCell).toList());
  }
  final detail = excel['Detail'];
  for (final row in detailRows) {
    detail.appendRow(row.map(_toCell).toList());
  }
  excel.delete('Sheet1');
  final bytes = excel.encode();
  if (bytes == null) throw StateError('Could not encode the spreadsheet.');
  return bytes;
}

/// Monthly team PDF bytes: summary table plus team pay total. The pay
/// figure is labelled as an estimate in the document itself.
Future<Uint8List> buildMonthlyPdfBytes({
  required String title,
  required List<TeamReportRow> rows,
  required String currency,
  required double teamTotalPay,
}) async {
  final doc = pw.Document();
  final headers = <String>[
    'Employee',
    'Present',
    'Absent',
    'Late',
    'Hours',
    'Regular',
    'Overtime',
    'Attend %',
    'Pay est. ($currency)',
  ];
  final data = rows
      .map(
        (r) => [
          r.employee.name,
          '${r.daysPresent}',
          '${r.daysAbsent}',
          '${r.lateDays}',
          r.totalHours.toStringAsFixed(1),
          r.regularHours.toStringAsFixed(1),
          r.overtimeHours.toStringAsFixed(1),
          '${r.attendancePercent.toStringAsFixed(0)}%',
          r.payEstimate.toStringAsFixed(2),
        ],
      )
      .toList();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (context) => [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Team monthly attendance summary. Pay figures are estimates '
          'from recorded hours and hourly rates, not a legal payslip. '
          'Unpaid leave is counted as 0 because leave is not tracked yet.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF39FF88),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Team pay estimate total: '
          '${teamTotalPay.toStringAsFixed(2)} $currency',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
  return doc.save();
}
