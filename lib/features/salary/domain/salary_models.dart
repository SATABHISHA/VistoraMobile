import 'package:vistora_mobile/core/api/api_parsing.dart';

class SalaryRosterPage {
  const SalaryRosterPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
    required this.year,
  });

  final List<SalaryRosterEmployee> items;
  final int page;
  final int lastPage;
  final int total;
  final int year;

  bool get hasMore => page < lastPage;
}

class SalaryRosterEmployee {
  const SalaryRosterEmployee({
    required this.employeeId,
    required this.code,
    required this.name,
    required this.status,
    this.email,
    this.mobile,
    this.salary,
  });

  final int employeeId;
  final String code;
  final String name;
  final String status;
  final String? email;
  final String? mobile;
  final SalaryStructureRecord? salary;

  factory SalaryRosterEmployee.fromJson(Map<String, dynamic> json) =>
      SalaryRosterEmployee(
        employeeId: asInt(json['employee_id']),
        code: json['emp_code']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Employee',
        status: json['status']?.toString() ?? 'active',
        email: asNullableString(json['email']),
        mobile: asNullableString(json['mobile']),
        salary: json['salary'] is Map
            ? SalaryStructureRecord.fromJson(asMap(json['salary']))
            : null,
      );
}

class SalaryEmployeeDetail {
  const SalaryEmployeeDetail({
    required this.employeeId,
    required this.code,
    required this.name,
    required this.structures,
    required this.revisions,
  });

  final int employeeId;
  final String code;
  final String name;
  final List<SalaryStructureRecord> structures;
  final List<SalaryRevisionRecord> revisions;

  factory SalaryEmployeeDetail.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final name =
        [employee['first_name'], employee['middle_name'], employee['last_name']]
            .where(
              (value) => value != null && value.toString().trim().isNotEmpty,
            )
            .join(' ');
    return SalaryEmployeeDetail(
      employeeId: asInt(employee['id']),
      code: employee['emp_code']?.toString() ?? '',
      name: name.isEmpty ? 'Employee' : name,
      structures: asList(
        json['structures'],
      ).map((value) => SalaryStructureRecord.fromJson(asMap(value))).toList(),
      revisions: asList(
        json['revisions'],
      ).map((value) => SalaryRevisionRecord.fromJson(asMap(value))).toList(),
    );
  }

  SalaryStructureRecord? forYear(int year) {
    for (final structure in structures) {
      if (structure.year == year) return structure;
    }
    return null;
  }
}

class SalaryStructureRecord {
  const SalaryStructureRecord({
    required this.id,
    required this.year,
    required this.payGroupName,
    required this.ctcAnnual,
    required this.grossMonthly,
    required this.deductionMonthly,
    required this.netMonthly,
    required this.snapshot,
  });

  final int id;
  final int year;
  final String payGroupName;
  final double ctcAnnual;
  final double grossMonthly;
  final double deductionMonthly;
  final double netMonthly;
  final Map<String, dynamic> snapshot;

  factory SalaryStructureRecord.fromJson(Map<String, dynamic> json) =>
      SalaryStructureRecord(
        id: asInt(json['id']),
        year: asInt(json['year']),
        payGroupName: json['pay_group_name']?.toString() ?? 'Salary structure',
        ctcAnnual: asDouble(json['ctc_annual']),
        grossMonthly: asDouble(json['gross_monthly']),
        deductionMonthly: asDouble(json['deduction_monthly']),
        netMonthly: asDouble(json['net_monthly']),
        snapshot: asMap(json['pay_group_snapshot_json']),
      );
}

class SalaryRevisionRecord {
  const SalaryRevisionRecord({
    required this.id,
    required this.year,
    required this.revisionDate,
    required this.incrementAmount,
    required this.actionStatus,
    required this.oldNetMonthly,
    required this.newNetMonthly,
    required this.arrearsDue,
    required this.arrearsStatus,
    this.arrearEffectiveDate,
  });

  final int id;
  final int year;
  final DateTime revisionDate;
  final DateTime? arrearEffectiveDate;
  final double incrementAmount;
  final String actionStatus;
  final double oldNetMonthly;
  final double newNetMonthly;
  final double arrearsDue;
  final String arrearsStatus;

  bool get canRollback =>
      actionStatus == 'applied' && arrearsStatus != 'disbursed';

  factory SalaryRevisionRecord.fromJson(Map<String, dynamic> json) =>
      SalaryRevisionRecord(
        id: asInt(json['id']),
        year: asInt(json['year']),
        revisionDate: asDateTime(json['revision_date']) ?? DateTime.now(),
        arrearEffectiveDate: asDateTime(json['arrear_effective_date']),
        incrementAmount: asDouble(json['increment_amount']),
        actionStatus: json['action_status']?.toString() ?? 'applied',
        oldNetMonthly: asDouble(json['old_net_monthly']),
        newNetMonthly: asDouble(json['new_net_monthly']),
        arrearsDue: asDouble(json['arrears_due']),
        arrearsStatus: json['arrears_status']?.toString() ?? 'none',
      );
}
