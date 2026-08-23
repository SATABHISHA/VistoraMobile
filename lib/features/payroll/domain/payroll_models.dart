import 'package:vistora_mobile/core/api/api_parsing.dart';

class PayrollCycleSummary {
  const PayrollCycleSummary({
    required this.id,
    required this.year,
    required this.month,
    required this.status,
    required this.totalPayroll,
    required this.mrExpenseTotal,
    required this.employees,
  });

  final int id;
  final int year;
  final int month;
  final String status;
  final double totalPayroll;
  final double mrExpenseTotal;
  final List<PayrollEmployeeSummary> employees;

  factory PayrollCycleSummary.fromJson(Map<String, dynamic> json) =>
      PayrollCycleSummary(
        id: asInt(json['id']),
        year: asInt(json['year']),
        month: asInt(json['month']),
        status: json['status']?.toString() ?? 'draft',
        totalPayroll: asDouble(json['total_payroll']),
        mrExpenseTotal: asDouble(json['mr_expense_total']),
        employees: asList(
          json['employees'],
        ).map((item) => PayrollEmployeeSummary.fromJson(asMap(item))).toList(),
      );
}

class PayrollEmployeeSummary {
  const PayrollEmployeeSummary({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    this.employeeEmail,
    this.employeeMobile,
    required this.status,
    required this.baseAmount,
    required this.grossAmount,
    required this.statutoryDeduction,
    required this.attendanceDeduction,
    required this.arrears,
    required this.mrExpense,
    required this.netPayable,
    required this.deductionDays,
    required this.paidLeaveDays,
    required this.pendingLeaveDays,
    required this.missingAttendanceDays,
    required this.holidayDays,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final String? employeeEmail;
  final String? employeeMobile;
  final String status;
  final double baseAmount;
  final double grossAmount;
  final double statutoryDeduction;
  final double attendanceDeduction;
  final double arrears;
  final double mrExpense;
  final double netPayable;
  final double deductionDays;
  final int paidLeaveDays;
  final int pendingLeaveDays;
  final int missingAttendanceDays;
  final int holidayDays;

  factory PayrollEmployeeSummary.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final snapshot = asMap(json['payload_snapshot_json']);
    final name =
        '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim();
    return PayrollEmployeeSummary(
      id: asInt(json['id']),
      employeeId: asInt(json['employee_id']),
      employeeName: name.isEmpty ? 'Employee' : name,
      employeeCode: employee['emp_code']?.toString() ?? '—',
      status: json['status']?.toString() ?? 'draft',
      employeeEmail: employee['work_email']?.toString(),
      employeeMobile: employee['mobile']?.toString(),
      baseAmount: asDouble(json['base_amount']),
      grossAmount: asDouble(json['gross_amount']),
      statutoryDeduction: asDouble(json['statutory_deduction_amount']),
      attendanceDeduction: asDouble(json['attendance_deduction_amount']),
      arrears: asDouble(json['arrears_amount']),
      mrExpense: asDouble(json['mr_expense_amount']),
      netPayable: asDouble(json['net_payable']),
      deductionDays: asDouble(snapshot['attendanceDeductionDays']),
      paidLeaveDays: asInt(snapshot['paidLeaveDays']),
      pendingLeaveDays: asInt(snapshot['pendingLeaveDays']),
      missingAttendanceDays: asInt(snapshot['missingAttendanceDays']),
      holidayDays: asInt(snapshot['holidayDays']),
    );
  }
}

class PayrollCollection {
  const PayrollCollection({
    required this.companyName,
    required this.cycles,
    required this.mrEnabled,
  });
  final String companyName;
  final List<PayrollCycleSummary> cycles;
  final bool mrEnabled;
}
