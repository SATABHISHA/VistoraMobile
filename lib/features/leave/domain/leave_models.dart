import 'package:vistora_mobile/core/api/api_parsing.dart';

class LeaveTypeBalance {
  const LeaveTypeBalance({
    required this.id,
    required this.code,
    required this.name,
    required this.credited,
    required this.used,
    required this.remaining,
  });

  final int id;
  final String code;
  final String name;
  final double credited;
  final double used;
  final double remaining;

  factory LeaveTypeBalance.fromJson(Map<String, dynamic> json) =>
      LeaveTypeBalance(
        id: asInt(json['leave_type_id'] ?? json['id']),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Leave',
        credited: asDouble(json['credited']),
        used: asDouble(json['used']),
        remaining: asDouble(json['remaining'] ?? json['balance']),
      );
}

class LeaveSummary {
  const LeaveSummary({
    required this.creditedTotal,
    required this.usedTotal,
    required this.remainingTotal,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.types,
    required this.absentMonth,
  });

  final double creditedTotal;
  final double usedTotal;
  final double remainingTotal;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int absentMonth;
  final List<LeaveTypeBalance> types;

  factory LeaveSummary.fromResponse(Map<String, dynamic> response) {
    final data = asMap(response['data']);
    final leave = asMap(data['leave']);
    return LeaveSummary(
      creditedTotal: asDouble(leave['credited_total']),
      usedTotal: asDouble(leave['used_total']),
      remainingTotal: asDouble(leave['remaining_total']),
      pendingCount: asInt(leave['pending_count']),
      approvedCount: asInt(leave['approved_count']),
      rejectedCount: asInt(leave['rejected_count']),
      types: asList(
        leave['breakup'],
      ).map((item) => LeaveTypeBalance.fromJson(asMap(item))).toList(),
      absentMonth: asInt(asMap(data['attendance'])['absent_month']),
    );
  }
}

class LeaveRequestItem {
  const LeaveRequestItem({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.status,
    this.reason,
    this.decisionNote,
    this.leaveTypeName,
    this.employeeId,
    this.employeeName,
    this.employeeCode,
  });

  final int id;
  final DateTime startDate;
  final DateTime endDate;
  final double days;
  final String status;
  final String? reason;
  final String? decisionNote;
  final String? leaveTypeName;
  final int? employeeId;
  final String? employeeName;
  final String? employeeCode;

  factory LeaveRequestItem.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final employeeName =
        '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim();
    return LeaveRequestItem(
      id: asInt(json['id']),
      startDate: asDateTime(json['start_date']) ?? DateTime.now(),
      endDate: asDateTime(json['end_date']) ?? DateTime.now(),
      days: asDouble(json['days']),
      status: json['status']?.toString() ?? 'pending',
      reason: asNullableString(json['reason']),
      decisionNote: asNullableString(json['decision_note']),
      leaveTypeName: asNullableString(asMap(json['leave_type'])['name']),
      employeeId: employee.isEmpty ? null : asInt(employee['id']),
      employeeName: employeeName.isEmpty ? null : employeeName,
      employeeCode: asNullableString(employee['emp_code']),
    );
  }
}

class LeaveApprovalOption {
  const LeaveApprovalOption({
    required this.leaveTypeId,
    required this.name,
    required this.code,
    required this.balance,
    required this.afterApproval,
  });
  final int leaveTypeId;
  final String name;
  final String code;
  final double balance;
  final double afterApproval;

  factory LeaveApprovalOption.fromJson(Map<String, dynamic> json) =>
      LeaveApprovalOption(
        leaveTypeId: asInt(json['leave_type_id']),
        name: json['name']?.toString() ?? 'Leave',
        code: json['code']?.toString() ?? '',
        balance: asDouble(json['balance']),
        afterApproval: asDouble(json['after_approval']),
      );
}
