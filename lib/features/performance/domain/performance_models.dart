import 'package:vistora_mobile/core/api/api_parsing.dart';

const performanceKpis = <String>[
  'quality',
  'timeliness',
  'teamwork',
  'initiative',
  'communication',
];

const performanceKpiLabels = <String, String>{
  'quality': 'Work quality',
  'timeliness': 'Timeliness',
  'teamwork': 'Teamwork',
  'initiative': 'Initiative',
  'communication': 'Communication',
};

class PerformanceEmployeeOption {
  const PerformanceEmployeeOption({
    required this.id,
    required this.code,
    required this.name,
    required this.roleType,
    this.department,
    this.designation,
  });

  final int id;
  final String code;
  final String name;
  final String roleType;
  final String? department;
  final String? designation;

  factory PerformanceEmployeeOption.fromJson(Map<String, dynamic> json) {
    final department = asMap(json['department']);
    final designation = asMap(json['designation']);
    final name = [
      json['first_name'],
      json['last_name'],
    ].where((item) => item != null).join(' ').trim();
    return PerformanceEmployeeOption(
      id: asInt(json['id']),
      code: json['emp_code']?.toString() ?? '',
      name: name.isEmpty ? json['emp_code']?.toString() ?? 'Employee' : name,
      roleType: json['role_type']?.toString() ?? 'Employee',
      department: asNullableString(department['name']),
      designation: asNullableString(designation['name']),
    );
  }
}

class PerformanceReviewItem {
  const PerformanceReviewItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.reviewMonth,
    required this.reviewYear,
    required this.quality,
    required this.timeliness,
    required this.teamwork,
    required this.initiative,
    required this.communication,
    required this.overallScore,
    this.comment,
    this.reviewerName,
    this.createdAt,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final int reviewMonth;
  final int reviewYear;
  final int quality;
  final int timeliness;
  final int teamwork;
  final int initiative;
  final int communication;
  final double overallScore;
  final String? comment;
  final String? reviewerName;
  final DateTime? createdAt;

  double score(String key) => switch (key) {
    'quality' => quality.toDouble(),
    'timeliness' => timeliness.toDouble(),
    'teamwork' => teamwork.toDouble(),
    'initiative' => initiative.toDouble(),
    'communication' => communication.toDouble(),
    _ => 0,
  };

  String get periodLabel => '${_months[reviewMonth - 1]} $reviewYear';

  factory PerformanceReviewItem.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final supervisor = asMap(json['supervisor']);
    final employeeName = [
      employee['first_name'],
      employee['last_name'],
    ].where((item) => item != null).join(' ').trim();
    final reviewerName = [
      supervisor['first_name'],
      supervisor['last_name'],
    ].where((item) => item != null).join(' ').trim();
    return PerformanceReviewItem(
      id: asInt(json['id']),
      employeeId: asInt(json['employee_id']),
      employeeName: employeeName.isEmpty
          ? employee['emp_code']?.toString() ?? 'Employee'
          : employeeName,
      employeeCode: employee['emp_code']?.toString() ?? '',
      reviewMonth: asInt(json['review_month'], 1),
      reviewYear: asInt(json['review_year'], DateTime.now().year),
      quality: asInt(json['quality']),
      timeliness: asInt(json['timeliness']),
      teamwork: asInt(json['teamwork']),
      initiative: asInt(json['initiative']),
      communication: asInt(json['communication']),
      overallScore: asDouble(json['overall_score']),
      comment: asNullableString(json['comment']),
      reviewerName: reviewerName.isEmpty ? null : reviewerName,
      createdAt: asDateTime(json['created_at']),
    );
  }
}

class PerformancePage {
  const PerformancePage({
    required this.reviews,
    required this.employees,
    required this.reviewableEmployees,
    this.currentEmployeeId,
    this.canManage = false,
  });

  final List<PerformanceReviewItem> reviews;
  final List<PerformanceEmployeeOption> employees;

  /// Employees this account is allowed to create/update/delete reviews for.
  ///
  /// This is intentionally separate from [employees]. The latter is the
  /// read-only visibility roster, while this list is the server-authorized
  /// review target roster.
  final List<PerformanceEmployeeOption> reviewableEmployees;
  final int? currentEmployeeId;
  final bool canManage;
}

const _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
