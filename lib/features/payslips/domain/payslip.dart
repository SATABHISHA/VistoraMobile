import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/payroll/domain/payroll_models.dart';

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
    required this.mrExpenseAmount,
    required this.netPayable,
    this.employeeEmail,
    this.employeeMobile,
    this.designation,
    this.department,
    this.releasedAt,
    this.generatedAt,
    this.deductionDays = 0,
    this.presentDays = 0,
    this.absentDays = 0,
    this.halfDays = 0,
    this.paidLeaveDays = 0,
    this.pendingLeaveDays = 0,
    this.missingAttendanceDays = 0,
    this.holidayDays = 0,
    this.components = const [],
    this.leaveBalances = const [],
  });

  final int id;
  final int year;
  final int month;
  final String employeeName;
  final String employeeCode;
  final String? employeeEmail;
  final String? employeeMobile;
  final String? designation;
  final String? department;
  final double grossAmount;
  final double baseAmount;
  final double statutoryDeduction;
  final double attendanceDeduction;
  final double arrearsAmount;
  final double mrExpenseAmount;
  final double netPayable;
  final DateTime? releasedAt;
  final DateTime? generatedAt;
  final double deductionDays;
  final int presentDays;
  final int absentDays;
  final double halfDays;
  final int paidLeaveDays;
  final int pendingLeaveDays;
  final int missingAttendanceDays;
  final int holidayDays;
  final List<PayslipComponent> components;
  final List<PayslipLeaveBalance> leaveBalances;

  double get totalDeductions => statutoryDeduction + attendanceDeduction;

  factory Payslip.fromJson(Map<String, dynamic> json) {
    final payroll = asMap(json['payroll_employee']);
    final employee = asMap(payroll['employee']);
    final cycle = asMap(payroll['payroll_cycle']);
    final snapshot = asMap(payroll['payload_snapshot_json']);
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
      employeeMobile: asNullableString(employee['mobile']),
      designation:
          asNullableString(snapshot['designation']) ??
          asNullableString(asMap(employee['designation'])['name']),
      department:
          asNullableString(snapshot['department']) ??
          asNullableString(asMap(employee['department'])['name']),
      grossAmount: asDouble(payroll['gross_amount']),
      baseAmount: asDouble(payroll['base_amount']),
      statutoryDeduction: asDouble(payroll['statutory_deduction_amount']),
      attendanceDeduction: asDouble(payroll['attendance_deduction_amount']),
      arrearsAmount: asDouble(payroll['arrears_amount']),
      mrExpenseAmount: asDouble(payroll['mr_expense_amount']),
      netPayable: asDouble(payroll['net_payable']),
      releasedAt: asDateTime(cycle['released_at']),
      generatedAt: asDateTime(json['generated_at']),
      deductionDays: asDouble(snapshot['attendanceDeductionDays']),
      presentDays: asInt(snapshot['present']),
      absentDays: asInt(snapshot['absent'] ?? snapshot['absentDays']),
      halfDays: asDouble(snapshot['halfDay'] ?? snapshot['halfDays']),
      paidLeaveDays: asInt(snapshot['paidLeaveDays']),
      pendingLeaveDays: asInt(snapshot['pendingLeaveDays']),
      missingAttendanceDays: asInt(snapshot['missingAttendanceDays']),
      holidayDays: asInt(snapshot['holidayDays']),
      components: asList(
        snapshot['components'],
      ).map((item) => PayslipComponent.fromJson(asMap(item))).toList(),
      leaveBalances: asMap(snapshot['leaveBalances']).entries
          .map(
            (entry) =>
                PayslipLeaveBalance.fromJson(entry.key, asMap(entry.value)),
          )
          .toList(),
    );
  }

  factory Payslip.fromPayroll({
    required PayrollCycleSummary cycle,
    required PayrollEmployeeSummary employee,
  }) => Payslip(
    id: employee.id,
    year: cycle.year,
    month: cycle.month,
    employeeName: employee.employeeName,
    employeeCode: employee.employeeCode,
    employeeEmail: employee.employeeEmail,
    employeeMobile: employee.employeeMobile,
    designation: employee.designation,
    department: employee.department,
    grossAmount: employee.grossAmount,
    baseAmount: employee.baseAmount,
    statutoryDeduction: employee.statutoryDeduction,
    attendanceDeduction: employee.attendanceDeduction,
    arrearsAmount: employee.arrears,
    mrExpenseAmount: employee.mrExpense,
    netPayable: employee.netPayable,
    deductionDays: employee.deductionDays,
    presentDays: employee.presentDays,
    absentDays: employee.absentDays,
    halfDays: employee.halfDays,
    paidLeaveDays: employee.paidLeaveDays,
    pendingLeaveDays: employee.pendingLeaveDays,
    missingAttendanceDays: employee.missingAttendanceDays,
    holidayDays: employee.holidayDays,
    components: employee.components
        .map(
          (item) => PayslipComponent(
            name: item.name,
            type: item.type,
            amount: item.amount,
          ),
        )
        .toList(),
    leaveBalances: employee.leaveBalances
        .map(
          (item) => PayslipLeaveBalance(
            code: item.code,
            name: item.name,
            credited: item.credited,
            used: item.used,
            balance: item.balance,
          ),
        )
        .toList(),
    releasedAt: cycle.status == 'released' ? DateTime.now() : null,
  );
}

class PayslipComponent {
  const PayslipComponent({
    required this.name,
    required this.type,
    required this.amount,
  });
  final String name;
  final String type;
  final double amount;

  factory PayslipComponent.fromJson(Map<String, dynamic> json) =>
      PayslipComponent(
        name: json['name']?.toString() ?? 'Component',
        type: json['type']?.toString() ?? 'Earning',
        amount: asDouble(json['amount'] ?? json['monthly']),
      );
}

class PayslipLeaveBalance {
  const PayslipLeaveBalance({
    required this.code,
    required this.name,
    required this.credited,
    required this.used,
    required this.balance,
  });
  final String code;
  final String name;
  final double credited;
  final double used;
  final double balance;

  factory PayslipLeaveBalance.fromJson(
    String code,
    Map<String, dynamic> json,
  ) => PayslipLeaveBalance(
    code: code,
    name: json['name']?.toString() ?? code.toUpperCase(),
    credited: asDouble(json['credited']),
    used: asDouble(json['used']),
    balance: asDouble(json['balance']),
  );
}

class PayslipCollection {
  const PayslipCollection({required this.companyName, required this.items});
  final String companyName;
  final List<Payslip> items;
}
