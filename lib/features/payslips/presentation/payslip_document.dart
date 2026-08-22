import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vistora_mobile/features/payslips/domain/payslip.dart';

Future<Uint8List> buildPayslipPdf({
  required Payslip payslip,
  required String companyName,
}) async {
  final document = pw.Document(
    title: 'Payslip ${payslip.periodLabel}',
    author: companyName,
  );
  final money = NumberFormat.currency(locale: 'en_IN', symbol: 'INR ');
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(38),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(height: 5, color: PdfColor.fromHex('#FF6A00')),
          pw.SizedBox(height: 18),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Employee Salary Statement',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'PAYSLIP',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(payslip.periodLabel),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            color: PdfColor.fromHex('#F9FAFB'),
            child: pw.Table(
              children: [
                _row(
                  'Employee',
                  payslip.employeeName,
                  'Employee Code',
                  payslip.employeeCode,
                ),
                _row(
                  'Email',
                  payslip.employeeEmail ?? '—',
                  'Released On',
                  payslip.releasedAt == null
                      ? '—'
                      : DateFormat.yMMMd().format(payslip.releasedAt!),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 25),
          pw.Text(
            'Salary details',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _amount('Gross Earnings', money.format(payslip.grossAmount)),
          _amount('Base Salary', money.format(payslip.baseAmount)),
          _amount(
            'Statutory Deductions',
            money.format(payslip.statutoryDeduction),
          ),
          _amount(
            'Attendance Deductions',
            money.format(payslip.attendanceDeduction),
          ),
          _amount('Arrears / Adjustments', money.format(payslip.arrearsAmount)),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            color: PdfColor.fromHex('#ECFDF5'),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Net Payable',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  money.format(payslip.netPayable),
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Center(
            child: pw.Text(
              'Computer-generated salary statement for $companyName • Payslip #${payslip.id}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    ),
  );
  return document.save();
}

pw.TableRow _row(String a, String b, String c, String d) =>
    pw.TableRow(children: [_field(a, b), _field(c, d)]);

pw.Widget _field(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.all(7),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label.toUpperCase(),
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    ],
  ),
);

pw.Widget _amount(String label, String value) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(vertical: 10),
  decoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
  ),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label),
      pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ],
  ),
);

extension PayslipPeriod on Payslip {
  String get periodLabel => DateFormat.yMMMM().format(DateTime(year, month));
}
