import 'package:vistora_mobile/core/api/api_parsing.dart';

class EmployeePage {
  const EmployeePage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<ManagedEmployee> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

class ManagedEmployee {
  const ManagedEmployee({
    required this.id,
    required this.code,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
    this.workEmail,
    this.mobile,
    this.branch,
    this.department,
    this.designation,
    this.username,
    this.ctcAnnual,
    this.netMonthly,
  });

  final int id;
  final String code;
  final String firstName;
  final String lastName;
  final String role;
  final String status;
  final String? workEmail;
  final String? mobile;
  final String? branch;
  final String? department;
  final String? designation;
  final String? username;
  final double? ctcAnnual;
  final double? netMonthly;

  String get name => '$firstName $lastName'.trim();
  bool get hasCredentials => username?.isNotEmpty == true;

  factory ManagedEmployee.fromJson(Map<String, dynamic> json) {
    final salary = asMap(json['current_salary']);
    final user = asMap(json['user']);
    return ManagedEmployee(
      id: asInt(json['id']),
      code: json['emp_code']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      role: json['role_type']?.toString() ?? 'Employee',
      status: json['status']?.toString() ?? 'inactive',
      workEmail: asNullableString(json['work_email']),
      mobile: asNullableString(json['mobile']),
      branch: asNullableString(asMap(json['branch'])['name']),
      department: asNullableString(asMap(json['department'])['name']),
      designation: asNullableString(asMap(json['designation'])['name']),
      username: asNullableString(user['username']),
      ctcAnnual: salary['ctc_annual'] == null
          ? null
          : asDouble(salary['ctc_annual']),
      netMonthly: salary['net_monthly'] == null
          ? null
          : asDouble(salary['net_monthly']),
    );
  }
}
