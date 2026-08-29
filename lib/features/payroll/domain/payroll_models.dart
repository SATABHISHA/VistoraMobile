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
    this.designation,
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
    required this.presentDays,
    required this.absentDays,
    required this.halfDays,
    required this.components,
    required this.leaveBalances,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final String? employeeEmail;
  final String? employeeMobile;
  final String? designation;
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
  final int presentDays;
  final int absentDays;
  final double halfDays;
  final List<PayrollComponent> components;
  final List<PayrollLeaveBalance> leaveBalances;

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
      designation:
          snapshot['designation']?.toString() ??
          asMap(employee['designation'])['name']?.toString(),
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
      presentDays: asInt(snapshot['present']),
      absentDays: asInt(snapshot['absent'] ?? snapshot['absentDays']),
      halfDays: asDouble(snapshot['halfDay'] ?? snapshot['halfDays']),
      components: asList(
        snapshot['components'],
      ).map((item) => PayrollComponent.fromJson(asMap(item))).toList(),
      leaveBalances: asMap(snapshot['leaveBalances']).entries
          .map(
            (entry) =>
                PayrollLeaveBalance.fromJson(entry.key, asMap(entry.value)),
          )
          .toList(),
    );
  }
}

class PayrollComponent {
  const PayrollComponent({
    required this.name,
    required this.type,
    required this.amount,
  });

  final String name;
  final String type;
  final double amount;

  factory PayrollComponent.fromJson(Map<String, dynamic> json) =>
      PayrollComponent(
        name: json['name']?.toString() ?? 'Component',
        type: json['type']?.toString() ?? 'Earning',
        amount: asDouble(json['amount'] ?? json['monthly']),
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'amount': amount,
  };

  PayrollComponent copyWith({String? name, String? type, double? amount}) =>
      PayrollComponent(
        name: name ?? this.name,
        type: type ?? this.type,
        amount: amount ?? this.amount,
      );
}

class PayrollLeaveBalance {
  const PayrollLeaveBalance({
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

  factory PayrollLeaveBalance.fromJson(
    String code,
    Map<String, dynamic> json,
  ) => PayrollLeaveBalance(
    code: code,
    name: json['name']?.toString() ?? code.toUpperCase(),
    credited: asDouble(json['credited']),
    used: asDouble(json['used']),
    balance: asDouble(json['balance']),
  );
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
