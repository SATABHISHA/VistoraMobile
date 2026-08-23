import 'package:vistora_mobile/core/api/api_parsing.dart';

class HrPage<T> {
  const HrPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });
  final List<T> items;
  final int page;
  final int lastPage;
  final int total;
  bool get hasMore => page < lastPage;
}

class HrEmployee {
  const HrEmployee({
    required this.id,
    required this.name,
    required this.code,
    this.userId,
    this.email,
    this.designation,
    this.joiningDate,
  });
  final int id;
  final int? userId;
  final String name;
  final String code;
  final String? email;
  final String? designation;
  final DateTime? joiningDate;

  factory HrEmployee.fromJson(Map<String, dynamic> json) {
    final designation = asMap(json['designation']);
    final name = [json['first_name'], json['middle_name'], json['last_name']]
        .where((item) => item != null && item.toString().trim().isNotEmpty)
        .join(' ');
    return HrEmployee(
      id: asInt(json['id']),
      userId: _intOrNull(json['user_id']),
      name: name.isEmpty ? 'Employee' : name,
      code: json['emp_code']?.toString() ?? '—',
      email: asNullableString(json['work_email'] ?? json['personal_email']),
      designation: asNullableString(
        designation['name'] ?? json['designation_name'],
      ),
      joiningDate: asDateTime(json['doj']),
    );
  }
}

class RecruitmentCandidate {
  const RecruitmentCandidate({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    this.phone,
    this.position,
    this.source,
    this.interviewCount = 0,
  });
  final int id;
  final String name;
  final String email;
  final String status;
  final String? phone;
  final String? position;
  final String? source;
  final int interviewCount;

  factory RecruitmentCandidate.fromJson(Map<String, dynamic> json) {
    final name = [json['first_name'], json['last_name']]
        .where((item) => item != null && item.toString().trim().isNotEmpty)
        .join(' ');
    return RecruitmentCandidate(
      id: asInt(json['id']),
      name: name.isEmpty ? 'Candidate' : name,
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'applied',
      phone: asNullableString(json['phone']),
      position: asNullableString(json['position']),
      source: asNullableString(json['source']),
      interviewCount: asList(json['interviews']).length,
    );
  }
}

class LetterTemplate {
  const LetterTemplate({
    required this.id,
    required this.name,
    required this.bodyHtml,
    required this.status,
  });
  final int id;
  final String name;
  final String bodyHtml;
  final String status;

  factory LetterTemplate.fromJson(Map<String, dynamic> json) => LetterTemplate(
    id: asInt(json['id']),
    name: json['name']?.toString() ?? 'Template',
    bodyHtml: json['body_html']?.toString() ?? '',
    status: json['status']?.toString() ?? 'active',
  );
}

class RecruitmentOffer {
  const RecruitmentOffer({
    required this.id,
    required this.candidateName,
    required this.candidateEmail,
    required this.position,
    required this.status,
    required this.offeredCtc,
    required this.startDate,
    required this.renderedHtml,
    this.templateName,
    this.generatedAt,
  });
  final int id;
  final String candidateName;
  final String candidateEmail;
  final String position;
  final String status;
  final double offeredCtc;
  final DateTime startDate;
  final String renderedHtml;
  final String? templateName;
  final DateTime? generatedAt;

  factory RecruitmentOffer.fromJson(Map<String, dynamic> json) {
    final candidate = asMap(json['candidate']);
    final template = asMap(json['template']);
    final name = [candidate['first_name'], candidate['last_name']]
        .where((item) => item != null && item.toString().trim().isNotEmpty)
        .join(' ');
    return RecruitmentOffer(
      id: asInt(json['id']),
      candidateName: name.isEmpty ? 'Candidate' : name,
      candidateEmail: candidate['email']?.toString() ?? '',
      position:
          json['position']?.toString() ??
          candidate['position']?.toString() ??
          '',
      status: json['status']?.toString() ?? 'generated',
      offeredCtc: asDouble(json['offered_ctc']),
      startDate: asDateTime(json['start_date']) ?? DateTime.now(),
      renderedHtml: json['rendered_html']?.toString() ?? '',
      templateName: asNullableString(template['name']),
      generatedAt: asDateTime(json['generated_at']),
    );
  }
}

class EmployeeLetter {
  const EmployeeLetter({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.renderedHtml,
    required this.status,
    this.templateName,
    this.generatedAt,
  });
  final int id;
  final String employeeName;
  final String employeeCode;
  final String renderedHtml;
  final String status;
  final String? templateName;
  final DateTime? generatedAt;

  factory EmployeeLetter.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final template = asMap(json['template']);
    final name = [employee['first_name'], employee['last_name']]
        .where((item) => item != null && item.toString().trim().isNotEmpty)
        .join(' ');
    return EmployeeLetter(
      id: asInt(json['id']),
      employeeName: name.isEmpty ? 'Employee' : name,
      employeeCode: employee['emp_code']?.toString() ?? '—',
      renderedHtml: json['rendered_html']?.toString() ?? '',
      status: json['status']?.toString() ?? 'generated',
      templateName: asNullableString(template['name']),
      generatedAt: asDateTime(json['generated_at']),
    );
  }
}

class FinalSettlementItem {
  const FinalSettlementItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.resignationDate,
    required this.lastWorkingDate,
    required this.salaryDue,
    required this.leaveEncashment,
    required this.gratuity,
    required this.bonus,
    required this.deductions,
    required this.netSettlement,
    required this.status,
    this.notes,
    this.slipNumber,
    this.disbursedAt,
  });
  final int id;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final DateTime resignationDate;
  final DateTime lastWorkingDate;
  final double salaryDue;
  final double leaveEncashment;
  final double gratuity;
  final double bonus;
  final double deductions;
  final double netSettlement;
  final String status;
  final String? notes;
  final String? slipNumber;
  final DateTime? disbursedAt;

  factory FinalSettlementItem.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final name = [employee['first_name'], employee['last_name']]
        .where((item) => item != null && item.toString().trim().isNotEmpty)
        .join(' ');
    return FinalSettlementItem(
      id: asInt(json['id']),
      employeeId: asInt(json['employee_id'] ?? employee['id']),
      employeeName: name.isEmpty ? 'Employee' : name,
      employeeCode: employee['emp_code']?.toString() ?? '—',
      resignationDate: asDateTime(json['resignation_date']) ?? DateTime.now(),
      lastWorkingDate: asDateTime(json['last_working_date']) ?? DateTime.now(),
      salaryDue: asDouble(json['salary_due']),
      leaveEncashment: asDouble(json['leave_encashment']),
      gratuity: asDouble(json['gratuity']),
      bonus: asDouble(json['bonus']),
      deductions: asDouble(json['deductions']),
      netSettlement: asDouble(json['net_settlement']),
      status: json['status']?.toString() ?? 'draft',
      notes: asNullableString(json['notes']),
      slipNumber: asNullableString(json['slip_number']),
      disbursedAt: asDateTime(json['disbursed_at']),
    );
  }
}

int? _intOrNull(Object? value) =>
    value == null ? null : int.tryParse(value.toString());
