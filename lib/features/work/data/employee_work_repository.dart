import 'package:vistora_mobile/core/api/api_client.dart';
import 'package:vistora_mobile/core/api/api_parsing.dart';
import 'package:vistora_mobile/features/work/domain/employee_work_models.dart';

class EmployeeWorkRepository {
  const EmployeeWorkRepository(this._api);
  final ApiClient _api;

  Future<List<EmployeeProject>> projects() async {
    final response = await _api.get(
      '/projects',
      queryParameters: {'perPage': 50},
    );
    return _items(
      response,
    ).map((item) => EmployeeProject.fromJson(asMap(item))).toList();
  }

  Future<void> submitProjectUpdate({
    required int projectId,
    required int assignmentId,
    required String periodType,
    required DateTime periodStart,
    DateTime? periodEnd,
    required int progressPercent,
    String? achievements,
    String? blockers,
    String? nextPlan,
  }) => _api.post(
    '/projects/$projectId/updates',
    data: {
      'assignment_id': assignmentId,
      'period_type': periodType,
      'period_start': _date(periodStart),
      'period_end': periodEnd == null ? null : _date(periodEnd),
      'progress_percent': progressPercent,
      'achievements': achievements,
      'blockers': blockers,
      'next_plan': nextPlan,
    },
  );

  Future<List<PerformanceReviewItem>> performance({int? employeeId}) async {
    final response = await _api.get(
      '/performance',
      queryParameters: {'employee_id': ?employeeId, 'perPage': 50},
    );
    return _items(
      response,
    ).map((item) => PerformanceReviewItem.fromJson(asMap(item))).toList();
  }

  Future<List<InterviewTask>> interviews() async {
    final response = await _api.get('/recruitment/interviews/mine');
    return _items(
      response,
    ).map((item) => InterviewTask.fromJson(asMap(item))).toList();
  }

  Future<void> submitInterviewFeedback({
    required int interviewId,
    required int rating,
    required String recommendation,
    required String feedback,
  }) => _api.post(
    '/recruitment/interviews/$interviewId/feedback',
    data: {
      'rating': rating,
      'recommendation': recommendation,
      'feedback': feedback,
    },
  );

  static List<dynamic> _items(Map<String, dynamic> response) {
    final data = asMap(response['data']);
    final page = asMap(data['items']);
    return asList(page['data'] ?? data['items']);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
