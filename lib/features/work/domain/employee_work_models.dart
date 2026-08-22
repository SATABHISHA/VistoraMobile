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

class PerformanceReviewItem {
  const PerformanceReviewItem({
    required this.id,
    required this.month,
    required this.year,
    required this.overallScore,
    required this.quality,
    required this.timeliness,
    required this.teamwork,
    required this.initiative,
    required this.communication,
    this.comment,
  });
  final int id;
  final int month;
  final int year;
  final double overallScore;
  final int quality;
  final int timeliness;
  final int teamwork;
  final int initiative;
  final int communication;
  final String? comment;

  factory PerformanceReviewItem.fromJson(Map<String, dynamic> json) =>
      PerformanceReviewItem(
        id: asInt(json['id']),
        month: asInt(json['review_month']),
        year: asInt(json['review_year']),
        overallScore: asDouble(json['overall_score']),
        quality: asInt(json['quality']),
        timeliness: asInt(json['timeliness']),
        teamwork: asInt(json['teamwork']),
        initiative: asInt(json['initiative']),
        communication: asInt(json['communication']),
        comment: asNullableString(json['comment']),
      );
}

class InterviewTask {
  const InterviewTask({
    required this.id,
    required this.candidateName,
    required this.position,
    required this.scheduledAt,
    required this.mode,
    required this.status,
    required this.feedback,
  });
  final int id;
  final String candidateName;
  final String position;
  final DateTime scheduledAt;
  final String mode;
  final String status;
  final List<InterviewFeedbackItem> feedback;

  InterviewFeedbackItem? feedbackBy(int userId) {
    for (final item in feedback) {
      if (item.panelistUserId == userId) return item;
    }
    return null;
  }

  factory InterviewTask.fromJson(Map<String, dynamic> json) {
    final candidate = asMap(json['candidate']);
    final name = [
      candidate['first_name'],
      candidate['last_name'],
    ].where((part) => part != null).join(' ').trim();
    return InterviewTask(
      id: asInt(json['id']),
      candidateName: name.isEmpty ? 'Candidate' : name,
      position: candidate['position']?.toString() ?? '',
      scheduledAt: asDateTime(json['scheduled_at']) ?? DateTime.now(),
      mode: json['mode']?.toString() ?? 'scheduled',
      status: json['status']?.toString() ?? 'scheduled',
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
