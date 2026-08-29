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
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(34),
      footer: (context) => pw.Center(
        child: pw.Text(
          'Computer-generated salary statement for $companyName  |  Payslip #${payslip.id}  |  Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
      ),
      build: (_) => [
        pw.Container(
          height: 6,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromHex('#F97316'),
                PdfColor.fromHex('#EC407A'),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 17),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Employee Salary Statement',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'PAYSLIP',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#F97316'),
                  ),
                ),
                pw.Text(
                  payslip.periodLabel,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FAFC'),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
          ),
          child: pw.Table(
            children: [
              _infoRow(
                'Employee',
                payslip.employeeName,
                'Employee Code',
                payslip.employeeCode,
              ),
              _infoRow(
                'Designation',
                payslip.designation ?? 'Not specified',
                'Payroll Period',
                payslip.periodLabel,
              ),
              _infoRow(
                'Email',
                payslip.employeeEmail ?? 'Not available',
                'Mobile',
                payslip.employeeMobile ?? 'Not available',
              ),
              _infoRow(
                'Released On',
                payslip.releasedAt == null
                    ? 'Not available'
                    : DateFormat.yMMMd().format(payslip.releasedAt!),
                'Status',
                'Released',
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        _sectionTitle('Salary breakup'),
        pw.SizedBox(height: 8),
        if (payslip.components.isNotEmpty)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#172033'),
                ),
                children: [
                  _tableCell('COMPONENT', header: true),
                  _tableCell('TYPE', header: true),
                  _tableCell('MONTHLY', header: true, alignRight: true),
                ],
              ),
              for (final component in payslip.components)
                pw.TableRow(
                  children: [
                    _tableCell(component.name),
                    _tableCell(component.type),
                    _tableCell(
                      money.format(component.amount),
                      alignRight: true,
                    ),
                  ],
                ),
            ],
          )
        else
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColor.fromHex('#F8FAFC'),
            child: pw.Text(
              'The released payroll contains summary amounts; no component snapshot was recorded for this cycle.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
        pw.SizedBox(height: 15),
        _amount('Gross Monthly', money.format(payslip.grossAmount)),
        _amount(
          'Statutory Deductions',
          '- ${money.format(payslip.statutoryDeduction)}',
          color: PdfColor.fromHex('#DC2626'),
        ),
        _amount(
          'Net Salary Before Attendance',
          money.format(payslip.baseAmount),
        ),
        _amount(
          'Attendance / LOP Deduction (${_days(payslip.deductionDays)} days)',
          '- ${money.format(payslip.attendanceDeduction)}',
          color: PdfColor.fromHex('#DC2626'),
        ),
        if (payslip.arrearsAmount > 0)
          _amount('Arrears / Adjustments', money.format(payslip.arrearsAmount)),
        if (payslip.mrExpenseAmount > 0)
          _amount(
            'Approved Field Expenses',
            money.format(payslip.mrExpenseAmount),
          ),
        pw.SizedBox(height: 13),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#ECFDF5'),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColor.fromHex('#86EFAC')),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'NET PAYABLE',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#166534'),
                ),
              ),
              pw.Text(
                money.format(payslip.netPayable),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#166534'),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        _sectionTitle('Attendance impact'),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _metric('PRESENT', '${payslip.presentDays}', '#0284C7'),
            pw.SizedBox(width: 8),
            _metric('ABSENT', '${payslip.absentDays}', '#DC2626'),
            pw.SizedBox(width: 8),
            _metric('HALF DAY', _days(payslip.halfDays), '#D97706'),
            pw.SizedBox(width: 8),
            _metric('PAID LEAVE', '${payslip.paidLeaveDays}', '#059669'),
          ],
        ),
        if (payslip.leaveBalances.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          _sectionTitle('Leave balance'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#172033'),
                ),
                children: [
                  _tableCell('LEAVE TYPE', header: true),
                  _tableCell('CREDITED', header: true, alignRight: true),
                  _tableCell('USED', header: true, alignRight: true),
                  _tableCell('REMAINING', header: true, alignRight: true),
                ],
              ),
              for (final balance in payslip.leaveBalances)
                pw.TableRow(
                  children: [
                    _tableCell(balance.name),
                    _tableCell(_days(balance.credited), alignRight: true),
                    _tableCell(_days(balance.used), alignRight: true),
                    _tableCell(_days(balance.balance), alignRight: true),
                  ],
                ),
            ],
          ),
        ],
        pw.SizedBox(height: 26),
      ],
    ),
  );
  return document.save();
}

pw.Widget _sectionTitle(String value) => pw.Text(
  value.toUpperCase(),
  style: pw.TextStyle(
    fontSize: 11,
    fontWeight: pw.FontWeight.bold,
    color: PdfColor.fromHex('#F97316'),
    letterSpacing: 1.1,
  ),
);

pw.TableRow _infoRow(String a, String b, String c, String d) =>
    pw.TableRow(children: [_field(a, b), _field(c, d)]);

pw.Widget _field(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.all(6),
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
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ),
    ],
  ),
);

pw.Widget _tableCell(
  String value, {
  bool header = false,
  bool alignRight = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  child: pw.Text(
    value,
    textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(
      fontSize: header ? 8 : 9,
      fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: header ? PdfColors.white : PdfColors.black,
    ),
  ),
);

pw.Widget _amount(String label, String value, {PdfColor? color}) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );

pw.Widget _metric(String label, String value, String color) => pw.Expanded(
  child: pw.Container(
    padding: const pw.EdgeInsets.all(9),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromHex('${color}12'),
      border: pw.Border.all(color: PdfColor.fromHex('${color}55')),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex(color),
          ),
        ),
      ],
    ),
  ),
);

String _days(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

extension PayslipPeriod on Payslip {
  String get periodLabel => DateFormat.yMMMM().format(DateTime(year, month));
}
