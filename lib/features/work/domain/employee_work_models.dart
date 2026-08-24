import 'package:vistora_mobile/core/api/api_parsing.dart';

class ProjectAssignmentItem {
  const ProjectAssignmentItem({
    required this.id,
    required this.employeeId,
    required this.role,
    required this.status,
    this.deadline,
  });
  final int id;
  final int employeeId;
  final String role;
  final String status;
  final DateTime? deadline;

  factory ProjectAssignmentItem.fromJson(Map<String, dynamic> json) =>
      ProjectAssignmentItem(
        id: asInt(json['id']),
        employeeId: asInt(json['employee_id']),
        role: json['role']?.toString() ?? 'Member',
        status: json['status']?.toString() ?? 'assigned',
        deadline: asDateTime(json['deadline']),
      );
}

class EmployeeProject {
  const EmployeeProject({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.healthStatus,
    required this.assignments,
  });
  final int id;
  final String code;
  final String name;
  final String status;
  final String healthStatus;
  final List<ProjectAssignmentItem> assignments;

  ProjectAssignmentItem? assignmentFor(int? employeeId) {
    if (employeeId == null) return null;
    for (final assignment in assignments) {
      if (assignment.employeeId == employeeId) return assignment;
    }
    return null;
  }

  factory EmployeeProject.fromJson(Map<String, dynamic> json) =>
      EmployeeProject(
        id: asInt(json['id']),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Project',
        status: json['status']?.toString() ?? 'active',
        healthStatus: json['health_status']?.toString() ?? 'green',
        assignments: asList(
          json['assignments'],
        ).map((item) => ProjectAssignmentItem.fromJson(asMap(item))).toList(),
      );
}

class InterviewTask {
  const InterviewTask({
    required this.id,
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
      candidateName: name.isEmpty ? 'Candidate' : name,
      candidateEmail: candidate['email']?.toString() ?? '',
      candidatePhone: asNullableString(candidate['phone']),
      position: candidate['position']?.toString() ?? '',
      scheduledAt: asDateTime(json['scheduled_at']) ?? DateTime.now(),
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
