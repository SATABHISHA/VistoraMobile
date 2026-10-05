import 'package:vistora_mobile/core/api/api_parsing.dart';

class ProjectUpdateItem {
  const ProjectUpdateItem({
    required this.id,
    required this.periodType,
    required this.periodStart,
    required this.progressPercent,
    this.periodEnd,
    this.achievements,
    this.blockers,
    this.nextPlan,
    this.createdAt,
  });

  final int id;
  final String periodType;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int progressPercent;
  final String? achievements;
  final String? blockers;
  final String? nextPlan;
  final DateTime? createdAt;

  factory ProjectUpdateItem.fromJson(Map<String, dynamic> json) =>
      ProjectUpdateItem(
        id: asInt(json['id']),
        periodType: json['period_type']?.toString() ?? 'update',
        periodStart: asDateTime(json['period_start']),
        periodEnd: asDateTime(json['period_end']),
        progressPercent: asInt(json['progress_percent']),
        achievements: asNullableString(json['achievements']),
        blockers: asNullableString(json['blockers']),
        nextPlan: asNullableString(json['next_plan']),
        createdAt: asDateTime(json['created_at']),
      );
}

class ProjectAssignmentItem {
  const ProjectAssignmentItem({
    required this.id,
    required this.employeeId,
    required this.role,
    required this.status,
    this.deadline,
    this.employeeName,
    this.employeeCode,
    this.employeeRoleType,
    this.updates = const [],
  });
  final int id;
  final int employeeId;
  final String role;
  final String status;
  final DateTime? deadline;
  final String? employeeName;
  final String? employeeCode;
  final String? employeeRoleType;
  final List<ProjectUpdateItem> updates;

  factory ProjectAssignmentItem.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    final name = [
      employee['first_name'],
      employee['last_name'],
    ].where((part) => part != null).join(' ').trim();
    return ProjectAssignmentItem(
      id: asInt(json['id']),
      employeeId: asInt(json['employee_id']),
      role: json['role']?.toString() ?? 'Member',
      status: json['status']?.toString() ?? 'assigned',
      deadline: asDateTime(json['deadline']),
      employeeName: name.isEmpty
          ? asNullableString(employee['emp_code'])
          : name,
      employeeCode: asNullableString(employee['emp_code']),
      employeeRoleType: asNullableString(employee['role_type']),
      updates: asList(
        json['updates'],
      ).map((item) => ProjectUpdateItem.fromJson(asMap(item))).toList(),
    );
  }
}

class EmployeeProject {
  const EmployeeProject({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.healthStatus,
    required this.assignments,
    this.supervisorId,
    this.supervisorName,
    this.startDate,
    this.endDate,
  });
  final int id;
  final String code;
  final String name;
  final String status;
  final String healthStatus;
  final List<ProjectAssignmentItem> assignments;
  final int? supervisorId;
  final String? supervisorName;
  final DateTime? startDate;
  final DateTime? endDate;

  ProjectAssignmentItem? assignmentFor(int? employeeId) {
    if (employeeId == null) return null;
    for (final assignment in assignments) {
      if (assignment.employeeId == employeeId) return assignment;
    }
    return null;
  }

  factory EmployeeProject.fromJson(Map<String, dynamic> json) {
    final assignments = asList(
      json['assignments'],
    ).map((item) => ProjectAssignmentItem.fromJson(asMap(item))).toList();
    final rawSupervisorId = asInt(json['supervisor_id']);
    ProjectAssignmentItem? supervisorAssignment;

    for (final assignment in assignments) {
      if (rawSupervisorId != 0 && assignment.employeeId == rawSupervisorId) {
        supervisorAssignment = assignment;
        break;
      }
      final roleType = assignment.employeeRoleType?.toLowerCase();
      if (rawSupervisorId == 0 &&
          (roleType == 'supervisor' ||
              assignment.role.toLowerCase() == 'supervisor')) {
        supervisorAssignment = assignment;
        break;
      }
    }

    return EmployeeProject(
      id: asInt(json['id']),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Project',
      status: json['status']?.toString() ?? 'active',
      healthStatus: json['health_status']?.toString() ?? 'green',
      supervisorId: rawSupervisorId == 0
          ? supervisorAssignment?.employeeId
          : rawSupervisorId,
      supervisorName:
          _personName(asMap(json['supervisor'])) ??
          supervisorAssignment?.employeeName,
      startDate: asDateTime(json['start_date']),
      endDate: asDateTime(json['end_date']),
      assignments: assignments,
    );
  }

  static String? _personName(Map<String, dynamic> person) {
    final name = [
      person['first_name'],
      person['last_name'],
    ].where((part) => part != null).join(' ').trim();
    return name.isEmpty ? asNullableString(person['emp_code']) : name;
  }
}

class ProjectMemberOption {
  const ProjectMemberOption({
    required this.id,
    required this.name,
    required this.code,
    required this.roleType,
    required this.status,
    this.department,
    this.designation,
    this.reportingManagerId,
  });

  final int id;
  final String name;
  final String code;
  final String roleType;
  final String status;
  final String? department;
  final String? designation;
  final int? reportingManagerId;

  factory ProjectMemberOption.fromJson(Map<String, dynamic> json) {
    final department = asMap(json['department']);
    final designation = asMap(json['designation']);
    final name = [
      json['first_name'],
      json['last_name'],
    ].where((part) => part != null).join(' ').trim();
    return ProjectMemberOption(
      id: asInt(json['id']),
      name: name.isEmpty ? json['emp_code']?.toString() ?? 'Employee' : name,
      code: json['emp_code']?.toString() ?? '',
      roleType: json['role_type']?.toString() ?? 'Employee',
      status: json['status']?.toString() ?? 'active',
      department: asNullableString(department['name']),
      designation: asNullableString(designation['name']),
      reportingManagerId: asInt(json['reporting_manager_id']) == 0
          ? null
          : asInt(json['reporting_manager_id']),
    );
  }
}

class ProjectManagementPage {
  const ProjectManagementPage({
    required this.projects,
    required this.assignableEmployees,
    this.currentEmployeeId,
  });

  final List<EmployeeProject> projects;
  final List<ProjectMemberOption> assignableEmployees;
  final int? currentEmployeeId;
}

class InterviewTask {
  const InterviewTask({
    required this.id,
    required this.candidateId,
    required this.candidateName,
    required this.candidateEmail,
    required this.position,
    required this.scheduledAt,
    required this.mode,
    required this.status,
    required this.feedback,
    this.candidatePhone,
    this.resumeName,
    this.notes,
  });
  final int id;
  final int candidateId;
  final String candidateName;
  final String candidateEmail;
  final String? candidatePhone;
  final String position;
  final DateTime scheduledAt;
  final String mode;
  final String status;
  final String? resumeName;
  final String? notes;
  final List<InterviewFeedbackItem> feedback;

  InterviewFeedbackItem? feedbackBy(int userId) {
    for (final item in feedback) {
      if (item.panelistUserId == userId) return item;
    }
    return null;
  }

  factory InterviewTask.fromJson(Map<String, dynamic> json) {
    final candidate = asMap(json['candidate']);
    final resume = asMap(candidate['resume']);
    final name = [
      candidate['first_name'],
      candidate['last_name'],
    ].where((part) => part != null).join(' ').trim();
    return InterviewTask(
      id: asInt(json['id']),
      candidateId: asInt(candidate['id']),
      candidateName: name.isEmpty ? 'Candidate' : name,
      candidateEmail: candidate['email']?.toString() ?? '',
      candidatePhone: asNullableString(candidate['phone']),
      position: candidate['position']?.toString() ?? '',
      // The API includes the tenant-local value for deterministic display;
      // fall back to the UTC instant for older server responses.
      scheduledAt:
          asTenantLocalDateTime(
            json['scheduled_at_local'],
            json['scheduled_at'],
          ) ??
          DateTime.now(),
      mode: json['mode']?.toString() ?? 'scheduled',
      status: json['status']?.toString() ?? 'scheduled',
      resumeName: asNullableString(resume['original_name']),
      notes: asNullableString(json['notes']),
      feedback: asList(
        json['feedback'],
      ).map((item) => InterviewFeedbackItem.fromJson(asMap(item))).toList(),
    );
  }
}

class InterviewTaskPage {
  const InterviewTaskPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<InterviewTask> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

class InterviewFeedbackItem {
  const InterviewFeedbackItem({
    required this.panelistUserId,
    required this.rating,
    required this.recommendation,
    required this.feedback,
  });
  final int panelistUserId;
  final int rating;
  final String recommendation;
  final String feedback;

  factory InterviewFeedbackItem.fromJson(Map<String, dynamic> json) =>
      InterviewFeedbackItem(
        panelistUserId: asInt(json['panelist_user_id']),
        rating: asInt(json['rating']),
        recommendation: json['recommendation']?.toString() ?? '',
        feedback: json['feedback']?.toString() ?? '',
      );
}
