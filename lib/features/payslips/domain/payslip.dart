import 'package:vistora_mobile/core/api/api_parsing.dart';

class Payslip {
  const Payslip({
    required this.id,
    required this.year,
    required this.month,
    required this.employeeName,
    required this.employeeCode,
    required this.grossAmount,
    required this.baseAmount,
    required this.statutoryDeduction,
    required this.attendanceDeduction,
    required this.arrearsAmount,
    required this.netPayable,
    this.employeeEmail,
    this.releasedAt,
    this.generatedAt,
  });

  final int id;
  final int year;
  final int month;
  final String employeeName;
  final String employeeCode;
  final String? employeeEmail;
  final double grossAmount;
  final double baseAmount;
  final double statutoryDeduction;
  final double attendanceDeduction;
  final double arrearsAmount;
  final double netPayable;
  final DateTime? releasedAt;
  final DateTime? generatedAt;

  double get totalDeductions => statutoryDeduction + attendanceDeduction;

  factory Payslip.fromJson(Map<String, dynamic> json) {
    final payroll = asMap(json['payroll_employee']);
    final employee = asMap(payroll['employee']);
    final cycle = asMap(payroll['payroll_cycle']);
    final name = [
      employee['first_name'],
      employee['last_name'],
    ].where((part) => part != null).join(' ').trim();
    return Payslip(
      id: asInt(json['id']),
      year: asInt(cycle['year']),
      month: asInt(cycle['month']),
      employeeName: name.isEmpty ? 'Employee' : name,
      employeeCode: employee['emp_code']?.toString() ?? '—',
      employeeEmail: asNullableString(employee['work_email']),
      grossAmount: asDouble(payroll['gross_amount']),
      baseAmount: asDouble(payroll['base_amount']),
      statutoryDeduction: asDouble(payroll['statutory_deduction_amount']),
      attendanceDeduction: asDouble(payroll['attendance_deduction_amount']),
      arrearsAmount: asDouble(payroll['arrears_amount']),
      netPayable: asDouble(payroll['net_payable']),
      releasedAt: asDateTime(cycle['released_at']),
      generatedAt: asDateTime(json['generated_at']),
    );
  }
}

class PayslipCollection {
  const PayslipCollection({required this.companyName, required this.items});
  final String companyName;
  final List<Payslip> items;
}
